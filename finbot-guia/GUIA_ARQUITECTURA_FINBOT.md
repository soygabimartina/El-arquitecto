# Guía de Arquitectura: FinBot

## ¿Qué es FinBot?

Es un **asistente de inversión conservador** para Binance que corre desde la terminal.
Cada vez que lo ejecutás:

1. Consulta tu saldo real en Binance (Spot + Earn)
2. Aplica un motor de reglas de inversión conservadoras
3. Le pide a Claude (API de Anthropic) que redacte un análisis en español con una recomendación
4. Te muestra todo en pantalla y **te pregunta si querés ejecutar la acción**
5. Si decís que sí, ejecuta la operación en Binance y deja todo registrado en un log

No es un bot automático: **vos das la orden final** cada vez (input `[s/n]`).

---

## Estructura de archivos

```
FinBot/
├── .env                    ← credenciales (no se sube a git)
├── requirements.txt        ← dependencias Python
├── monitor.py              ← orquestador principal (punto de entrada)
├── reglas.py               ← motor de decisiones (las 7 reglas)
├── notificaciones.py       ← envío de mensajes por Telegram
└── log/
    └── finbot_2026-06-07.log   ← un archivo de log por día
```

---

## Diagrama de flujo

```
                    ┌─────────────┐
                    │   .env      │  (credenciales)
                    └──────┬──────┘
                           │
                           ▼
   ┌───────────────────────────────────────────────┐
   │                  monitor.py                    │
   │           (orquestador / punto de entrada)     │
   └───────────────────────────────────────────────┘
       │                │                   │
       │ 1. consulta    │ 3. evalúa con     │ 5. notifica
       ▼                ▼                   ▼
 ┌───────────┐   ┌─────────────┐   ┌─────────────────┐
 │ Binance   │   │ reglas.py   │   │ notificaciones.py│
 │ API       │   │ (R1...R7)   │   │ (Telegram)       │
 │           │   │             │   │                  │
 │ - Spot    │   │ Devuelve:   │   │ Envía resumen +  │
 │ - Earn    │   │ acción      │   │ recomendación    │
 │ - APY     │   │ sugerida +  │   │                  │
 └───────────┘   │ justif.     │   └─────────────────┘
                 └──────┬──────┘
                        │ 4. arma el prompt y
                        │    consulta a Claude
                        ▼
                 ┌─────────────┐
                 │ API Claude  │ → análisis en español:
                 │ (Anthropic) │   resumen, recomendación,
                 └─────────────┘   justificación, monto
                        │
                        ▼
                 ┌─────────────┐
                 │  Terminal   │ → muestra todo y pregunta:
                 │  [s/n]      │   "¿Ejecutar? [s/n]"
                 └──────┬──────┘
                        │
              s ┌───────┴───────┐ n
                ▼               ▼
        ┌───────────────┐  ┌──────────┐
        │ Ejecuta orden │  │ Cancela, │
        │ en Binance    │  │ no hace  │
        │ (subscribe /  │  │ nada     │
        │  redeem)      │  │          │
        └───────┬───────┘  └────┬─────┘
                └─────────┬─────┘
                          ▼
                  ┌───────────────┐
                  │  log/finbot_  │  ← registra todo con timestamp
                  │  YYYY-MM-DD   │
                  │  .log         │
                  └───────────────┘
```

---

## Detalle de cada módulo

### `.env` — Credenciales
Variables necesarias (nunca se commitean a git):

| Variable | Para qué sirve |
|---|---|
| `BINANCE_API_KEY` / `BINANCE_SECRET` | Conexión a tu cuenta de Binance |
| `ANTHROPIC_API_KEY` | Para pedirle el análisis a Claude |
| `TELEGRAM_TOKEN` / `TELEGRAM_CHAT_ID` | Para recibir notificaciones |

> Si `BINANCE_SECRET` no está configurado, FinBot entra en **modo solo lectura**:
> puede mostrarte el análisis pero no puede ejecutar ninguna operación.

---

### `monitor.py` — Orquestador principal
Es el script que ejecutás (`python monitor.py`). Se encarga de coordinar todo:

1. Carga las credenciales del `.env`
2. Llama a la API de Binance para traer:
   - Saldo Spot por activo (USDT, FDUSD, USDC, BTC)
   - Productos activos en Earn (Flexible y Fixed)
   - APY actual de cada producto disponible
3. Pasa esos datos a `reglas.py` para que decida qué conviene hacer
4. Arma un prompt con los datos + las reglas y se lo envía a la API de Claude
   (modelo recomendado: `claude-sonnet-4-6`, el actual de la familia Sonnet 4)
5. Imprime en terminal: resumen, recomendación, justificación, monto sugerido
6. Pregunta `¿Ejecutar la acción recomendada? [s/n]`
7. Si confirmás, llama a Binance para suscribir o rescatar el monto exacto
8. Llama a `notificaciones.py` para avisarte por Telegram
9. Escribe cada paso en `log/finbot_YYYY-MM-DD.log`

---

### `reglas.py` — Motor de decisiones
Contiene la lógica pura (sin llamadas externas) que evalúa el estado de la cuenta
contra 7 reglas y devuelve una acción sugerida + el motivo. Pensalo como una
función `evaluar(saldos, productos_earn) → (accion, monto, justificacion)`.

| Regla | Qué controla |
|---|---|
| **R1** | Siempre dejar un colchón mínimo de **$15 USDT** en Spot (prioridad máxima — se evalúa primero y bloquea cualquier otra acción que la viole) |
| **R2** | Si el Spot USDT supera **$20**, sugerir mover el excedente a Flexible Savings |
| **R3** | Suscribir a Fixed 30 días **solo si**: la diferencia de APY vs. Flexible es ≥ 1% **y** el monto a mover es ≤ $30 |
| **R4** | Si otra stablecoin (FDUSD/USDC) ofrece un APY ≥ 0.8% más que el USDT Flexible, sugerir migración **parcial** (máximo 40% del saldo de esa moneda) |
| **R5** | Si la diferencia de APY entre dos opciones es **menor a 0.5%**, no recomendar ningún movimiento (el cambio no compensa el riesgo/esfuerzo) |
| **R6** | No ejecutar **más de una operación por día** — se valida leyendo el log del día actual antes de sugerir una acción |
| **R7** | Si hay un error de conexión con Binance, o el saldo total no coincide con lo esperado en más de **$1**, **frenar todo** y emitir una alerta sin sugerir ninguna acción |

**Orden de evaluación sugerido**: R7 (errores) → R6 (límite diario) → R1 (colchón
mínimo) → R5 (diferencia de APY) → R3/R4 (oportunidades) → R2 (excedente). Esto
asegura que las reglas de seguridad (errores, colchón, límite diario) siempre
tengan prioridad sobre las de oportunidad.

---

### `notificaciones.py` — Envío por Telegram
Módulo simple que arma el mensaje (con el mismo resumen que se ve en terminal)
y lo envía al chat configurado vía la API de Telegram (`sendMessage`).
Se invoca después de que el usuario confirma o cancela, para tener un registro
fuera de la terminal.

---

### `log/` — Auditoría diaria
Cada corrida agrega líneas con timestamp a `log/finbot_YYYY-MM-DD.log`:

```
2026-06-07 09:00:03 | CONSULTA | Spot: 32.40 USDT, 0 FDUSD | Earn Flexible APY: 4.2%
2026-06-07 09:00:05 | RECOMENDACION | Mover 17.40 USDT a Flexible Savings (R2)
2026-06-07 09:00:21 | USUARIO | Confirmó ejecución [s]
2026-06-07 09:00:23 | EJECUCION | Suscripción Flexible Savings: 17.40 USDT - OK
```

Este log cumple dos funciones: **auditoría** (qué se hizo y cuándo) y
**control de la regla R6** (el bot lee el log del día para saber si ya operó).

---

## Reglas de seguridad transversales (aplican siempre, en todo el código)

Estas no son parte del motor de decisión — son **invariantes de seguridad** que
el código debe respetar sin excepción:

- 🔒 Nunca loguear ni imprimir las API keys (ni completas ni parciales)
- 🔒 Nunca mover más del **85% del capital total** en una sola operación
- 🔒 Operar **solo** con stablecoins: USDT, FDUSD, USDC (nunca BTC ni otros activos volátiles)
- 🔒 Si el saldo total es **menor a $20**, no recomendar ningún movimiento (capital insuficiente para operar con margen de seguridad)
- 🔒 Si falta `BINANCE_SECRET`, el bot opera en **modo solo lectura** (puede analizar pero no ejecutar)

---

## requirements.txt (dependencias sugeridas)

```
python-binance
python-telegram-bot
anthropic
python-dotenv
```

---

## Cómo se correría (una vez construido)

```bash
# Instalar dependencias
pip install -r requirements.txt

# Completar credenciales
cp .env.example .env   # y editar con tus claves

# Ejecutar
python monitor.py
```

Salida esperada en terminal (ejemplo):

```
=== FinBot — análisis 2026-06-07 09:00 ===

📊 ESTADO ACTUAL
  Spot:  32.40 USDT | 0.00 FDUSD | 0.00 USDC | 0.00012 BTC
  Earn Flexible USDT: APY 4.2% (saldo: 100.00 USDT)
  Earn Fixed 30d USDT: APY 5.1%

💡 RECOMENDACIÓN
  Mover 17.40 USDT de Spot → Flexible Savings

📋 JUSTIFICACIÓN (regla R2)
  Tu saldo en Spot ($32.40) supera el colchón mínimo recomendado ($15).
  El excedente ($17.40) puede generar 4.2% APY en Flexible Savings sin
  perder liquidez inmediata.

¿Ejecutar la acción recomendada? [s/n]: _
```

---

## Para automatizar la corrida diaria (Windows)

Una vez construido y probado en modo manual, se puede programar con el
Programador de tareas de Windows para que corra solo, por ejemplo, todos los
días a las 9 AM. Esto es un paso posterior — primero conviene correrlo
manualmente varios días para validar que las recomendaciones tienen sentido.
