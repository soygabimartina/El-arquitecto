"""
Validador de reglas de inversión. Cada regla devuelve (ok: bool, motivo: str).
"""
from datetime import datetime
from typing import Tuple

from config import InvestmentRules
from agent.binance_client import Portfolio


class RulesValidator:
    def __init__(self, rules: InvestmentRules):
        self.rules = rules

    def check_operating_hours(self) -> Tuple[bool, str]:
        hour = datetime.now().hour
        if self.rules.operating_hour_start <= hour < self.rules.operating_hour_end:
            return True, ""
        return False, (
            f"Fuera de horario operativo "
            f"({self.rules.operating_hour_start}:00–{self.rules.operating_hour_end}:00). "
            f"Hora actual: {hour}:00."
        )

    def check_daily_ops(self, ops_today: int) -> Tuple[bool, str]:
        if ops_today < self.rules.max_daily_ops:
            return True, ""
        return False, (
            f"Límite diario de operaciones alcanzado "
            f"({self.rules.max_daily_ops} operaciones/día)."
        )

    def check_liquidity(self, portfolio: Portfolio, amount_to_lock: float) -> Tuple[bool, str]:
        total = portfolio.total_value()
        if total <= 0:
            return False, "El saldo total es cero."
        liquid_after = portfolio.liquid_value() - amount_to_lock
        pct_after = liquid_after / total
        if pct_after >= self.rules.min_liquidity_pct:
            return True, ""
        return False, (
            f"La operación dejaría solo {pct_after:.1%} en liquidez "
            f"(mínimo requerido: {self.rules.min_liquidity_pct:.0%})."
        )

    def check_operation_size(self, portfolio: Portfolio, amount: float) -> Tuple[bool, str]:
        total = portfolio.total_value()
        if total <= 0:
            return False, "El saldo total es cero."
        pct = amount / total
        if pct <= self.rules.max_single_op_pct:
            return True, ""
        return False, (
            f"El monto ({pct:.1%} del capital) supera el límite de operación única "
            f"({self.rules.max_single_op_pct:.0%})."
        )

    def check_apr_diff(self, apr_from: float, apr_to: float) -> Tuple[bool, str]:
        diff = apr_to - apr_from
        if diff >= self.rules.min_apr_diff:
            return True, ""
        return False, (
            f"La diferencia de APR ({diff:.2f}%) es menor al mínimo requerido "
            f"({self.rules.min_apr_diff:.1f}%) para justificar el movimiento."
        )

    def check_balance_consistency(
        self,
        current: dict,
        previous: dict,
    ) -> Tuple[bool, str]:
        """Detecta si algún saldo difiere más de drift_pct respecto al registro anterior."""
        if not previous:
            return True, ""
        for key, prev_val in previous.items():
            curr_val = current.get(key, 0.0)
            if prev_val == 0:
                continue
            drift = abs(curr_val - prev_val) / prev_val
            if drift > self.rules.balance_drift_alert_pct:
                return False, (
                    f"Inconsistencia detectada en {key}: "
                    f"antes ${prev_val:.2f}, ahora ${curr_val:.2f} "
                    f"(diferencia {drift:.1%})."
                )
        return True, ""

    def check_asset_allowed(self, asset: str) -> Tuple[bool, str]:
        if asset in self.rules.allowed_assets:
            return True, ""
        return False, (
            f"El activo {asset} no está en la lista permitida "
            f"({', '.join(self.rules.allowed_assets)}). "
            f"Se requiere instrucción explícita del usuario para operar con otros activos."
        )
