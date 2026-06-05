import os
from dataclasses import dataclass, field
from typing import List


@dataclass
class InvestmentRules:
    min_liquidity_pct: float = 0.20       # 20% mínimo en liquidez inmediata
    max_single_op_pct: float = 0.30       # 30% máximo por operación
    max_daily_ops: int = 3                 # 3 operaciones máximo por día
    min_apr_diff: float = 0.5             # diferencia mínima de APR para recomendar movimiento
    balance_drift_alert_pct: float = 0.05 # 5% de diferencia dispara alerta de inconsistencia
    allowed_assets: List[str] = field(default_factory=lambda: ["USDT", "USDC"])
    operating_hour_start: int = 8         # 08:00 hora local
    operating_hour_end: int = 22          # 22:00 hora local


@dataclass
class AppConfig:
    # Binance
    binance_api_key: str = ""
    binance_api_secret: str = ""
    binance_testnet: bool = False

    # Telegram
    telegram_bot_token: str = ""
    telegram_chat_id: str = ""

    # Comportamiento
    check_interval_minutes: int = 60      # frecuencia de análisis automático
    state_file: str = "state.json"        # archivo de estado persistente

    # Reglas de inversión
    rules: InvestmentRules = field(default_factory=InvestmentRules)


def load_config() -> AppConfig:
    cfg = AppConfig(
        binance_api_key=os.getenv("BINANCE_API_KEY", ""),
        binance_api_secret=os.getenv("BINANCE_API_SECRET", ""),
        binance_testnet=os.getenv("BINANCE_TESTNET", "false").lower() == "true",
        telegram_bot_token=os.getenv("TELEGRAM_BOT_TOKEN", ""),
        telegram_chat_id=os.getenv("TELEGRAM_CHAT_ID", ""),
        check_interval_minutes=int(os.getenv("CHECK_INTERVAL_MINUTES", "60")),
        state_file=os.getenv("STATE_FILE", "state.json"),
    )
    return cfg
