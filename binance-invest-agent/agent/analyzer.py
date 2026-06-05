"""
Motor de análisis: compara el portafolio actual con los productos disponibles
y genera recomendaciones concretas respetando las reglas de inversión.
"""
import logging
from dataclasses import dataclass, field
from typing import List, Optional, Tuple

from config import InvestmentRules
from agent.binance_client import Portfolio, EarnProduct, FlexiblePosition, LockedPosition
from agent.rules import RulesValidator
from agent.state import StateManager, PendingOperation

logger = logging.getLogger(__name__)


@dataclass
class Alert:
    kind: str           # "apr_drop" | "idle_funds" | "locked_expiry" | "inconsistency" | "conn_error"
    message: str


@dataclass
class Recommendation:
    action: str                     # "move" | "maintain" | "reallocate"
    asset: str
    amount: float
    from_product: str
    to_product: str
    current_apr: float
    target_apr: float
    reason: str
    risks: List[str] = field(default_factory=list)


@dataclass
class Analysis:
    portfolio: Portfolio
    total_value: float
    liquid_value: float
    liquid_pct: float
    flexible_apr: float             # APR promedio ponderado de posiciones flexible
    locked_apr: float               # APR promedio ponderado de posiciones locked
    best_flexible_product: Optional[EarnProduct]
    best_locked_products: List[EarnProduct]
    recommendation: Optional[Recommendation]
    alerts: List[Alert] = field(default_factory=list)


class InvestmentAnalyzer:
    def __init__(self, rules: InvestmentRules, state_manager: StateManager):
        self.rules = rules
        self.validator = RulesValidator(rules)
        self.state = state_manager

    def analyze(
        self,
        portfolio: Portfolio,
        flexible_products: List[EarnProduct],
        locked_products: List[EarnProduct],
        ops_today: int,
    ) -> Analysis:
        total = portfolio.total_value()
        liquid = portfolio.liquid_value()
        liquid_pct = liquid / total if total > 0 else 0.0

        current_balances = portfolio.flat_balances()
        prev_balances = self.state.state.last_balances
        prev_apr_rates = self.state.state.last_apr_rates

        alerts: List[Alert] = []

        # Consistencia de saldos
        ok, msg = self.validator.check_balance_consistency(current_balances, prev_balances)
        if not ok:
            alerts.append(Alert(kind="inconsistency", message=msg))

        # Fondos ociosos en spot (solo spot free, no flexible)
        idle_spot = sum(b.free for b in portfolio.spot.values())
        if idle_spot > 10:  # umbral mínimo $10
            alerts.append(Alert(
                kind="idle_funds",
                message=(
                    f"Hay ${idle_spot:.2f} en spot sin ganar intereses. "
                    f"Considerá moverlos a Simple Earn."
                ),
            ))

        # Locked expirando pronto (< 48 hs)
        for pos in portfolio.locked:
            if 0 <= pos.days_remaining <= 2:
                alerts.append(Alert(
                    kind="locked_expiry",
                    message=(
                        f"Posición locked de {pos.asset} (${pos.amount:.2f}) "
                        f"vence en {pos.days_remaining} día(s) "
                        f"({pos.expiry_date.strftime('%Y-%m-%d')})."
                    ),
                ))

        # Caída de APR en flexible
        for pos in portfolio.flexible:
            key = f"{pos.asset}_flexible"
            prev_apr = prev_apr_rates.get(key)
            if prev_apr is not None and (prev_apr - pos.apr) >= 0.5:
                alerts.append(Alert(
                    kind="apr_drop",
                    message=(
                        f"APR flexible de {pos.asset} bajó de {prev_apr:.2f}% "
                        f"a {pos.apr:.2f}% (caída de {prev_apr - pos.apr:.2f}%)."
                    ),
                ))

        # APR promedio de posiciones actuales
        flex_weighted = self._weighted_apr(
            [(p.amount, p.apr) for p in portfolio.flexible]
        )
        locked_weighted = self._weighted_apr(
            [(p.amount, p.apr) for p in portfolio.locked]
        )

        # Mejor producto flexible disponible
        best_flex = max(
            (p for p in flexible_products if p.asset in self.rules.allowed_assets),
            key=lambda p: p.apr,
            default=None,
        )

        # Mejores productos locked (por asset, el de mayor APR)
        best_locked: List[EarnProduct] = []
        for asset in self.rules.allowed_assets:
            candidates = [p for p in locked_products if p.asset == asset]
            if candidates:
                best_locked.append(max(candidates, key=lambda p: p.apr))

        # Generar recomendación si aplica
        recommendation = self._build_recommendation(
            portfolio=portfolio,
            total=total,
            liquid=liquid,
            liquid_pct=liquid_pct,
            best_flex=best_flex,
            best_locked=best_locked,
            ops_today=ops_today,
            has_inconsistency=any(a.kind == "inconsistency" for a in alerts),
        )

        return Analysis(
            portfolio=portfolio,
            total_value=total,
            liquid_value=liquid,
            liquid_pct=liquid_pct,
            flexible_apr=flex_weighted,
            locked_apr=locked_weighted,
            best_flexible_product=best_flex,
            best_locked_products=best_locked,
            recommendation=recommendation,
            alerts=alerts,
        )

    def _weighted_apr(self, pairs: List[Tuple[float, float]]) -> float:
        total_amount = sum(a for a, _ in pairs)
        if total_amount == 0:
            return 0.0
        return sum(a * apr for a, apr in pairs) / total_amount

    def _build_recommendation(
        self,
        portfolio: Portfolio,
        total: float,
        liquid: float,
        liquid_pct: float,
        best_flex: Optional[EarnProduct],
        best_locked: List[EarnProduct],
        ops_today: int,
        has_inconsistency: bool,
    ) -> Optional[Recommendation]:

        # Siempre frenamos si hay inconsistencia
        if has_inconsistency:
            return None

        # Verificar horario
        ok, _ = self.validator.check_operating_hours()
        if not ok:
            return None

        # Verificar operaciones del día
        ok, _ = self.validator.check_daily_ops(ops_today)
        if not ok:
            return None

        idle_spot = sum(b.free for b in portfolio.spot.values())

        # Caso 1: hay fondos ociosos en spot, mover a flexible
        if idle_spot > 10 and best_flex is not None:
            current_apr = 0.0  # en spot no generan interés
            ok, _ = self.validator.check_apr_diff(current_apr, best_flex.apr)
            if ok:
                # calcular cuánto podemos mover respetando liquidez mínima
                max_by_liquidity = liquid - (total * self.rules.min_liquidity_pct)
                max_by_size = total * self.rules.max_single_op_pct
                amount = min(idle_spot, max_by_liquidity, max_by_size)
                amount = max(0.0, amount)
                if amount >= max(best_flex.min_purchase, 1.0):
                    ok_liq, _ = self.validator.check_liquidity(portfolio, amount)
                    ok_size, _ = self.validator.check_operation_size(portfolio, amount)
                    if ok_liq and ok_size:
                        return Recommendation(
                            action="move",
                            asset=best_flex.asset,
                            amount=round(amount, 2),
                            from_product=f"Spot ({best_flex.asset})",
                            to_product=f"Simple Earn Flexible ({best_flex.asset})",
                            current_apr=0.0,
                            target_apr=best_flex.apr,
                            reason=(
                                f"Fondos ociosos en spot generando 0% APR. "
                                f"Flexible ofrece {best_flex.apr:.2f}% APR con liquidez inmediata."
                            ),
                            risks=[
                                "Las tasas APR flexible son variables y pueden bajar.",
                                "El rescate tarda hasta 1 día hábil en procesarse.",
                            ],
                        )

        # Caso 2: posición flexible existente con APR menor al mejor locked disponible
        for flex_pos in portfolio.flexible:
            for locked_prod in best_locked:
                if locked_prod.asset != flex_pos.asset:
                    continue
                ok, _ = self.validator.check_apr_diff(flex_pos.apr, locked_prod.apr)
                if not ok:
                    continue
                # respetar liquidez: no mover todo lo flexible
                max_by_liquidity = portfolio.liquid_value() - (total * self.rules.min_liquidity_pct)
                max_by_size = total * self.rules.max_single_op_pct
                amount = min(flex_pos.amount, max_by_liquidity, max_by_size)
                amount = max(0.0, amount)
                if amount < max(locked_prod.min_purchase, 1.0):
                    continue
                ok_liq, _ = self.validator.check_liquidity(portfolio, amount)
                ok_size, _ = self.validator.check_operation_size(portfolio, amount)
                if ok_liq and ok_size:
                    return Recommendation(
                        action="reallocate",
                        asset=locked_prod.asset,
                        amount=round(amount, 2),
                        from_product=f"Simple Earn Flexible ({flex_pos.asset}, {flex_pos.apr:.2f}% APR)",
                        to_product=(
                            f"Simple Earn Locked {locked_prod.duration_days}d "
                            f"({locked_prod.asset}, {locked_prod.apr:.2f}% APR)"
                        ),
                        current_apr=flex_pos.apr,
                        target_apr=locked_prod.apr,
                        reason=(
                            f"El producto locked ofrece {locked_prod.apr - flex_pos.apr:.2f}% "
                            f"más de APR por {locked_prod.duration_days} días. "
                            f"Se mantiene liquidez mínima requerida."
                        ),
                        risks=[
                            f"Los fondos quedarán bloqueados por {locked_prod.duration_days} días.",
                            "No se puede rescatar anticipadamente en la mayoría de los productos locked.",
                            "Si necesitás liquidez urgente antes del vencimiento, no podrás acceder.",
                        ],
                    )

        return None  # sin recomendación activa
