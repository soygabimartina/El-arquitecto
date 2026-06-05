"""
Bot de Telegram con manejo de conversación para confirmación de operaciones.
Recibe CONFIRMAR o CANCELAR del usuario y ejecuta o descarta la operación pendiente.
"""
import logging
from typing import Callable, Awaitable

from telegram import Update
from telegram.constants import ParseMode
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

logger = logging.getLogger(__name__)

# Tipos para los callbacks
ConfirmCallback = Callable[[], Awaitable[str]]
CancelCallback = Callable[[], Awaitable[str]]


class TelegramBot:
    def __init__(
        self,
        token: str,
        chat_id: str,
        on_confirm: ConfirmCallback,
        on_cancel: CancelCallback,
    ):
        self._token = token
        self._chat_id = str(chat_id)
        self._on_confirm = on_confirm
        self._on_cancel = on_cancel
        self._app = ApplicationBuilder().token(token).build()
        self._register_handlers()

    def _register_handlers(self) -> None:
        self._app.add_handler(CommandHandler("start", self._handle_start))
        self._app.add_handler(CommandHandler("estado", self._handle_estado))
        self._app.add_handler(
            MessageHandler(filters.TEXT & ~filters.COMMAND, self._handle_text)
        )

    async def _handle_start(self, update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
        await update.message.reply_text(
            "🤖 *Agente de inversiones activo.*\n"
            "Recibirás análisis automáticos y alertas.\n"
            "Respondé *CONFIRMAR* o *CANCELAR* cuando haya una operación pendiente.",
            parse_mode=ParseMode.MARKDOWN,
        )

    async def _handle_estado(self, update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
        # El análisis se dispara desde el scheduler, no desde Telegram.
        # Este comando es solo informativo.
        await update.message.reply_text(
            "ℹ️ El agente corre análisis automáticos según el intervalo configurado.\n"
            "Si hay una operación pendiente, respondé *CONFIRMAR* o *CANCELAR*.",
            parse_mode=ParseMode.MARKDOWN,
        )

    async def _handle_text(self, update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
        if str(update.effective_chat.id) != self._chat_id:
            return

        text = update.message.text.strip().upper()

        if text == "CONFIRMAR":
            result = await self._on_confirm()
            await update.message.reply_text(result, parse_mode=ParseMode.MARKDOWN)
        elif text == "CANCELAR":
            result = await self._on_cancel()
            await update.message.reply_text(result, parse_mode=ParseMode.MARKDOWN)
        else:
            await update.message.reply_text(
                "ℹ️ Para responder a una recomendación enviá *CONFIRMAR* o *CANCELAR*.",
                parse_mode=ParseMode.MARKDOWN,
            )

    async def send(self, message: str) -> None:
        await self._app.bot.send_message(
            chat_id=self._chat_id,
            text=message,
            parse_mode=ParseMode.MARKDOWN,
        )

    def run_polling(self) -> None:
        """Bloquea el hilo y corre el bot en modo polling."""
        self._app.run_polling(drop_pending_updates=True)
