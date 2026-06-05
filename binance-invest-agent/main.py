"""
Punto de entrada del agente de inversiones.

Corre dos hilos en paralelo:
  1. Scheduler: analiza el portafolio cada CHECK_INTERVAL_MINUTES y envía resultados por Telegram.
  2. Bot de Telegram: escucha CONFIRMAR / CANCELAR del usuario y ejecuta operaciones aprobadas.
"""
import asyncio
import logging
import sys
import threading
import time
from datetime import datetime, timezone

from dotenv import load_dotenv

load_dotenv()

from config import load_config
from agent.binance_client import BinanceClient
from agent.analyzer import InvestmentAnalyzer
from agent.state import StateManager, PendingOperation
from agent.formatter import (
    format_analysis,
    format_recommendation,
    format_no_action,
    format_alerts,
    format_executed,
    format_cancelled,
    format_rule_violation,
    format_error,
)
from agent.telegram_bot import TelegramBot

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)


def run_analysis(
    cfg,
    binance: BinanceClient,
    analyzer: InvestmentAnalyzer,
    state: StateManager,
    telegram: TelegramBot,
) -> None:
    logger.info("Iniciando análisis de portafolio...")
    try:
        portfolio = binance.get_portfolio(cfg.rules.allowed_assets)
        flex_products = binance.get_available_flexible_products(cfg.rules.allowed_assets)
        locked_products = binance.get_available_locked_products(cfg.rules.allowed_assets)
    except Exception as e:
        msg = format_error(f"No se pudo conectar a Binance: {e}")
        asyncio.run(telegram.send(msg))
        logger.error("Error de conexión: %s", e)
        return

    analysis = analyzer.analyze(
        portfolio=portfolio,
        flexible_products=flex_products,
        locked_products=locked_products,
        ops_today=state.ops_today(),
    )

    # Persistir saldos y tasas actuales
    current_balances = portfolio.flat_balances()
    state.update_balances(current_balances)
    apr_rates = {}
    for pos in portfolio.flexible:
        apr_rates[f"{pos.asset}_flexible"] = pos.apr
    state.update_apr_rates(apr_rates)

    # Enviar análisis
    asyncio.run(telegram.send(format_analysis(analysis)))

    # Enviar alertas (cada una por separado para mayor visibilidad)
    for alert_msg in format_alerts(analysis.alerts):
        asyncio.run(telegram.send(alert_msg))

    # Si hay inconsistencia, no enviar recomendación
    if any(a.kind == "inconsistency" for a in analysis.alerts):
        logger.warning("Análisis suspendido por inconsistencia de saldos.")
        return

    # Enviar recomendación si hay una
    if analysis.recommendation:
        rec = analysis.recommendation
        # Guardar en estado para cuando el usuario responda
        state.set_pending(PendingOperation(
            action=rec.action,
            asset=rec.asset,
            amount=rec.amount,
            from_product=rec.from_product,
            to_product=rec.to_product,
            estimated_apr=rec.target_apr,
            reason=rec.reason,
        ))
        asyncio.run(telegram.send(format_recommendation(rec)))
    else:
        asyncio.run(telegram.send(format_no_action()))

    logger.info("Análisis completado. Total: $%.2f | Liquidez: %.1f%%",
                analysis.total_value, analysis.liquid_pct * 100)


def scheduler_loop(cfg, binance, analyzer, state, telegram):
    """Ejecuta el análisis periódicamente."""
    interval_sec = cfg.check_interval_minutes * 60
    while True:
        try:
            run_analysis(cfg, binance, analyzer, state, telegram)
        except Exception as e:
            logger.error("Error inesperado en análisis: %s", e)
            asyncio.run(telegram.send(format_error(str(e))))
        time.sleep(interval_sec)


async def on_confirm(binance: BinanceClient, state: StateManager, cfg) -> str:
    pending = state.get_pending()
    if pending is None:
        return "ℹ️ No hay operación pendiente de confirmación."

    logger.info("Usuario confirmó operación: %s $%.2f %s → %s",
                pending.action, pending.amount, pending.from_product, pending.to_product)

    # Re-verificar reglas antes de ejecutar (puede haber pasado tiempo)
    portfolio = binance.get_portfolio(cfg.rules.allowed_assets)
    from agent.rules import RulesValidator
    validator = RulesValidator(cfg.rules)

    checks = [
        validator.check_operating_hours(),
        validator.check_daily_ops(state.ops_today()),
        validator.check_operation_size(portfolio, pending.amount),
        validator.check_liquidity(portfolio, pending.amount),
        validator.check_asset_allowed(pending.asset),
    ]

    for ok, reason in checks:
        if not ok:
            state.clear_pending()
            return format_rule_violation(reason)

    # Ejecutar según el tipo de operación
    success = False
    try:
        flex_products = binance.get_available_flexible_products(cfg.rules.allowed_assets)
        locked_products = binance.get_available_locked_products(cfg.rules.allowed_assets)

        if pending.action == "move":
            # Spot → Flexible
            target = next(
                (p for p in flex_products if p.asset == pending.asset), None
            )
            if target:
                success = binance.subscribe_flexible(target.product_id, pending.amount)

        elif pending.action == "reallocate":
            # Flexible → Locked: primero rescatar del flexible, luego suscribir locked
            flex_pos = next(
                (p for p in portfolio.flexible if p.asset == pending.asset), None
            )
            target_locked = next(
                (p for p in locked_products
                 if p.asset == pending.asset and p.apr >= pending.estimated_apr - 0.1),
                None,
            )
            if flex_pos and target_locked:
                redeemed = binance.redeem_flexible(flex_pos.product_id, pending.amount)
                if redeemed:
                    # Pequeña espera para que el rescate se acredite en spot
                    time.sleep(3)
                    success = binance.subscribe_locked(target_locked.product_id, pending.amount)

    except Exception as e:
        state.clear_pending()
        return format_error(f"Error ejecutando operación: {e}")

    if success:
        state.increment_ops()
        state.clear_pending()
        from agent.analyzer import Recommendation
        rec = Recommendation(
            action=pending.action,
            asset=pending.asset,
            amount=pending.amount,
            from_product=pending.from_product,
            to_product=pending.to_product,
            current_apr=0.0,
            target_apr=pending.estimated_apr,
            reason=pending.reason,
        )
        return format_executed(rec)
    else:
        state.clear_pending()
        return format_error("La operación falló en Binance. Verificá manualmente tu cuenta.")


async def on_cancel(state: StateManager) -> str:
    state.clear_pending()
    return format_cancelled()


def main():
    cfg = load_config()

    missing = []
    if not cfg.binance_api_key:
        missing.append("BINANCE_API_KEY")
    if not cfg.binance_api_secret:
        missing.append("BINANCE_API_SECRET")
    if not cfg.telegram_bot_token:
        missing.append("TELEGRAM_BOT_TOKEN")
    if not cfg.telegram_chat_id:
        missing.append("TELEGRAM_CHAT_ID")
    if missing:
        print(f"ERROR: Variables de entorno faltantes: {', '.join(missing)}")
        print("Copiá .env.example a .env y completá los valores.")
        sys.exit(1)

    state = StateManager(cfg.state_file)
    binance = BinanceClient(
        api_key=cfg.binance_api_key,
        api_secret=cfg.binance_api_secret,
        testnet=cfg.binance_testnet,
    )
    analyzer = InvestmentAnalyzer(rules=cfg.rules, state_manager=state)

    telegram = TelegramBot(
        token=cfg.telegram_bot_token,
        chat_id=cfg.telegram_chat_id,
        on_confirm=lambda: on_confirm(binance, state, cfg),
        on_cancel=lambda: on_cancel(state),
    )

    # El scheduler corre en un hilo background
    scheduler_thread = threading.Thread(
        target=scheduler_loop,
        args=(cfg, binance, analyzer, state, telegram),
        daemon=True,
    )
    scheduler_thread.start()
    logger.info(
        "Agente iniciado. Intervalo de análisis: %d min. Horario operativo: %d:00–%d:00.",
        cfg.check_interval_minutes,
        cfg.rules.operating_hour_start,
        cfg.rules.operating_hour_end,
    )

    # El bot de Telegram bloquea el hilo principal
    telegram.run_polling()


if __name__ == "__main__":
    main()
