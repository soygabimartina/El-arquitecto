"""Tests de las reglas de inversión (sin dependencias externas)."""
import pytest
from unittest.mock import patch
from datetime import datetime

from config import InvestmentRules
from agent.rules import RulesValidator
from agent.binance_client import Portfolio, SpotBalance, FlexiblePosition


def make_portfolio(spot_free=1000.0, flexible=500.0) -> Portfolio:
    p = Portfolio()
    p.spot = {"USDT": SpotBalance(asset="USDT", free=spot_free, locked=0.0)}
    if flexible > 0:
        p.flexible = [FlexiblePosition(asset="USDT", amount=flexible, apr=4.0, product_id="prod1")]
    return p


@pytest.fixture
def rules():
    return InvestmentRules()


@pytest.fixture
def validator(rules):
    return RulesValidator(rules)


# --- Horario operativo ---

def test_within_operating_hours(validator):
    with patch("agent.rules.datetime") as mock_dt:
        mock_dt.now.return_value = datetime(2026, 6, 5, 12, 0)
        ok, msg = validator.check_operating_hours()
    assert ok
    assert msg == ""


def test_outside_operating_hours(validator):
    with patch("agent.rules.datetime") as mock_dt:
        mock_dt.now.return_value = datetime(2026, 6, 5, 23, 0)
        ok, msg = validator.check_operating_hours()
    assert not ok
    assert "Fuera de horario" in msg


# --- Operaciones diarias ---

def test_ops_within_limit(validator):
    ok, _ = validator.check_daily_ops(2)
    assert ok


def test_ops_at_limit(validator):
    ok, msg = validator.check_daily_ops(3)
    assert not ok
    assert "Límite diario" in msg


# --- Liquidez mínima ---

def test_liquidity_ok(validator):
    p = make_portfolio(spot_free=1000.0, flexible=500.0)  # total=1500, liquid=1500
    ok, _ = validator.check_liquidity(p, amount_to_lock=800.0)  # liquid_after=700 (46.7%)
    assert ok


def test_liquidity_too_low(validator):
    p = make_portfolio(spot_free=200.0, flexible=100.0)  # total=300, liquid=300
    ok, msg = validator.check_liquidity(p, amount_to_lock=250.0)  # liquid_after=50 (16.7%)
    assert not ok
    assert "liquidez" in msg


# --- Tamaño de operación ---

def test_operation_size_ok(validator):
    p = make_portfolio(spot_free=1000.0, flexible=0.0)
    ok, _ = validator.check_operation_size(p, 200.0)  # 20%
    assert ok


def test_operation_size_too_large(validator):
    p = make_portfolio(spot_free=1000.0, flexible=0.0)
    ok, msg = validator.check_operation_size(p, 400.0)  # 40%
    assert not ok
    assert "límite de operación única" in msg


# --- Diferencia de APR ---

def test_apr_diff_sufficient(validator):
    ok, _ = validator.check_apr_diff(3.0, 4.0)  # diff=1.0%
    assert ok


def test_apr_diff_insufficient(validator):
    ok, msg = validator.check_apr_diff(4.0, 4.3)  # diff=0.3%
    assert not ok
    assert "menor al mínimo" in msg


# --- Consistencia de saldos ---

def test_balance_consistent(validator):
    curr = {"USDT_spot": 1000.0}
    prev = {"USDT_spot": 1030.0}  # 3% diff
    ok, _ = validator.check_balance_consistency(curr, prev)
    assert ok


def test_balance_inconsistent(validator):
    curr = {"USDT_spot": 800.0}
    prev = {"USDT_spot": 1000.0}  # 20% diff
    ok, msg = validator.check_balance_consistency(curr, prev)
    assert not ok
    assert "Inconsistencia" in msg


# --- Activo permitido ---

def test_asset_allowed(validator):
    ok, _ = validator.check_asset_allowed("USDT")
    assert ok
    ok, _ = validator.check_asset_allowed("USDC")
    assert ok


def test_asset_not_allowed(validator):
    ok, msg = validator.check_asset_allowed("BTC")
    assert not ok
    assert "lista permitida" in msg
