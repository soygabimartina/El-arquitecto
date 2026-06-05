"""
Persiste el estado del agente entre ejecuciones: saldos anteriores, conteo diario
de operaciones y la operación pendiente de confirmación del usuario.
"""
import json
import os
from dataclasses import dataclass, asdict, field
from datetime import date
from typing import Optional, Dict, Any


@dataclass
class PendingOperation:
    action: str           # "move" | "maintain" | "reallocate"
    asset: str
    amount: float
    from_product: str
    to_product: str
    estimated_apr: float
    reason: str


@dataclass
class AgentState:
    last_balances: Dict[str, float] = field(default_factory=dict)   # {"USDT_spot": 1000, ...}
    last_apr_rates: Dict[str, float] = field(default_factory=dict)  # {"USDT_flexible": 4.5, ...}
    ops_date: str = ""                                               # "2026-06-05"
    ops_count_today: int = 0
    pending_operation: Optional[Dict[str, Any]] = None              # serialized PendingOperation


class StateManager:
    def __init__(self, path: str):
        self._path = path
        self._state = self._load()

    def _load(self) -> AgentState:
        if not os.path.exists(self._path):
            return AgentState()
        try:
            with open(self._path, "r") as f:
                data = json.load(f)
            s = AgentState(**data)
            # reset daily counter if new day
            if s.ops_date != str(date.today()):
                s.ops_date = str(date.today())
                s.ops_count_today = 0
            return s
        except Exception:
            return AgentState()

    def _save(self) -> None:
        with open(self._path, "w") as f:
            json.dump(asdict(self._state), f, indent=2)

    @property
    def state(self) -> AgentState:
        return self._state

    def update_balances(self, balances: Dict[str, float]) -> None:
        self._state.last_balances = balances
        self._save()

    def update_apr_rates(self, rates: Dict[str, float]) -> None:
        self._state.last_apr_rates = rates
        self._save()

    def increment_ops(self) -> None:
        today = str(date.today())
        if self._state.ops_date != today:
            self._state.ops_date = today
            self._state.ops_count_today = 0
        self._state.ops_count_today += 1
        self._save()

    def set_pending(self, op: PendingOperation) -> None:
        self._state.pending_operation = asdict(op)
        self._save()

    def clear_pending(self) -> None:
        self._state.pending_operation = None
        self._save()

    def get_pending(self) -> Optional[PendingOperation]:
        if self._state.pending_operation is None:
            return None
        return PendingOperation(**self._state.pending_operation)

    def ops_today(self) -> int:
        today = str(date.today())
        if self._state.ops_date != today:
            return 0
        return self._state.ops_count_today
