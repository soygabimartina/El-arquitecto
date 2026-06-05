"""
Genera los mensajes de Telegram con el formato exacto definido en la especificación.
"""
from datetime import datetime
from typing import List

from agent.analyzer import Analysis, Alert, Recommendation


def format_analysis(analysis: Analysis) -> str:
    p = analysis.portfolio
    total = analysis.total_value
    liquid = analysis.liquid_value
    liquid_pct = analysis.liquid_pct

    flex_lines = []
    for pos in p.flexible:
        flex_lines.append(f"    • {pos.asset}: ${pos.amount:,.2f} (APR: {pos.apr:.2f}%)")

    locked_lines = []
    for pos in p.locked:
        locked_lines.append(
            f"    • {pos.asset}: ${pos.amount:,.2f} "
            f"(APR: {pos.apr:.2f}%, vence: {pos.expiry_date.strftime('%Y-%m-%d')}, "
            f"{pos.days_remaining}d restantes)"
        )

    spot_lines = []
    for asset, b in p.spot.items():
        spot_lines.append(f"    • {asset}: ${b.total:,.2f} (free: ${b.free:,.2f})")

    flex_section = "\n".join(flex_lines) if flex_lines else "    • Sin posiciones"
    locked_section = "\n".join(locked_lines) if locked_lines else "    • Sin posiciones"
    spot_section = "\n".join(spot_lines) if spot_lines else "    • Sin saldo"

    msg = f"""📊 *ANÁLISIS* — {datetime.now().strftime('%Y-%m-%d %H:%M')}

• Saldo total: *${total:,.2f}*
• En liquidez inmediata: *${liquid:,.2f}* ({liquid_pct:.1%})

🏦 *Spot:*
{spot_section}

💧 *Simple Earn Flexible:*
{flex_section}

🔒 *Simple Earn Locked:*
{locked_section}"""

    return msg


def format_recommendation(rec: Recommendation) -> str:
    action_label = {
        "move": "Mover",
        "maintain": "Mantener",
        "reallocate": "Reasignar",
    }.get(rec.action, rec.action.capitalize())

    risks_text = "\n".join(f"  • {r}" for r in rec.risks)

    msg = f"""
💡 *RECOMENDACIÓN*

• Acción: {action_label}
• Monto: *${rec.amount:,.2f}*
• Desde: {rec.from_product}
• Hacia: {rec.to_product}
• APR actual: {rec.current_apr:.2f}%  →  APR estimado: *{rec.target_apr:.2f}%*
• Motivo: {rec.reason}

⚠️ *RIESGOS*
{risks_text}

🔐 *REQUIERE APROBACIÓN*
Respondé *CONFIRMAR* para ejecutar o *CANCELAR* para ignorar."""

    return msg


def format_no_action() -> str:
    return (
        "✅ *Sin recomendaciones*\n"
        "El portafolio está bien posicionado. "
        "No hay movimientos que justifiquen una operación en este momento."
    )


def format_alert(alert: Alert) -> str:
    icons = {
        "apr_drop": "📉",
        "idle_funds": "💤",
        "locked_expiry": "⏰",
        "inconsistency": "🚨",
        "conn_error": "❌",
    }
    icon = icons.get(alert.kind, "⚠️")
    kind_labels = {
        "apr_drop": "CAÍDA DE APR",
        "idle_funds": "FONDOS OCIOSOS",
        "locked_expiry": "POSICIÓN POR VENCER",
        "inconsistency": "INCONSISTENCIA DE SALDO — OPERACIONES SUSPENDIDAS",
        "conn_error": "ERROR DE CONEXIÓN CON BINANCE",
    }
    label = kind_labels.get(alert.kind, alert.kind.upper())
    return f"{icon} *ALERTA: {label}*\n{alert.message}"


def format_alerts(alerts: List[Alert]) -> List[str]:
    return [format_alert(a) for a in alerts]


def format_executed(rec: Recommendation) -> str:
    return (
        f"✅ *Operación ejecutada*\n"
        f"Se movieron ${rec.amount:,.2f} de {rec.from_product} "
        f"a {rec.to_product}."
    )


def format_cancelled() -> str:
    return "↩️ Operación cancelada. Sin cambios."


def format_rule_violation(reason: str) -> str:
    return f"🚫 *Operación bloqueada por regla de inversión*\n{reason}"


def format_error(message: str) -> str:
    return f"❌ *Error*\n{message}"
