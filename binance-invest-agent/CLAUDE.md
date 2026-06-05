# Agente de Inversiones Binance + Telegram

Sos un agente de inversiones conservador automatizado conectado a Binance y Telegram.

## Stack
- **Python 3.11+**
- `python-binance` — cliente oficial de la API de Binance
- `python-telegram-bot` — bot de Telegram con soporte async
- `python-dotenv` — manejo de variables de entorno

## Estructura
```
binance-invest-agent/
├── main.py              # Punto de entrada: scheduler + bot de Telegram
├── config.py            # Configuración y reglas de inversión
├── agent/
│   ├── binance_client.py  # Wrapper de Binance API
│   ├── telegram_bot.py    # Bot de Telegram + handlers
│   ├── analyzer.py        # Motor de análisis y recomendaciones
│   ├── rules.py           # Validador de reglas de inversión
│   ├── formatter.py       # Formateo de mensajes para Telegram
│   └── state.py           # Estado persistente (state.json)
└── tests/
    └── test_rules.py      # Tests de las reglas de inversión
```

## Flujo de ejecución
1. El scheduler corre en un hilo background cada `CHECK_INTERVAL_MINUTES`
2. Llama a Binance API para obtener saldos spot + Simple Earn (flexible y locked)
3. Obtiene productos disponibles y sus APR actuales
4. El analyzer evalúa el portafolio contra las reglas y genera una recomendación
5. Se envían alertas por Telegram si corresponde
6. Se envía el análisis + recomendación al usuario por Telegram
7. El usuario responde CONFIRMAR o CANCELAR
8. Si confirma, se re-verifican las reglas y se ejecuta la operación en Binance

## Reglas de inversión (hardcodeadas en config.py)
- Mínimo 20% en liquidez inmediata (spot free + flexible earn)
- Máximo 30% del capital por operación
- Máximo 3 operaciones por día
- Diferencia mínima de APR de 0.5% para justificar un movimiento
- Solo USDT y USDC (a menos que el usuario lo cambie explícitamente)
- Solo operar entre 8:00 y 22:00 hora local
- Nunca ejecutar sin CONFIRMAR del usuario

## Setup
```bash
cp .env.example .env
# completar BINANCE_API_KEY, BINANCE_API_SECRET, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
pip install -r requirements.txt
python main.py
```

## Tests
```bash
pytest tests/ -v
```

## Reglas de desarrollo
- NUNCA ejecutar operaciones en Binance sin confirmación explícita del usuario
- NUNCA recomendar futuros, margin, apalancamiento ni activos volátiles
- Siempre re-verificar las reglas de inversión antes de ejecutar, incluso después de CONFIRMAR
- El archivo state.json persiste el estado entre reinicios; no borrarlo sin avisar al usuario
- Para agregar nuevas reglas, modificar InvestmentRules en config.py y RulesValidator en rules.py
