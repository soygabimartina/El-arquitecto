"""
Wrapper sobre la Binance API para obtener saldos spot, posiciones en Simple Earn
(flexible y locked) y tasas APR disponibles para USDT y USDC.
"""
import logging
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional

from binance.client import Client
from binance.exceptions import BinanceAPIException

logger = logging.getLogger(__name__)


@dataclass
class SpotBalance:
    asset: str
    free: float
    locked: float

    @property
    def total(self) -> float:
        return self.free + self.locked


@dataclass
class FlexiblePosition:
    asset: str
    amount: float
    apr: float          # APR actual en porcentaje (e.g. 4.5)
    product_id: str


@dataclass
class LockedPosition:
    asset: str
    amount: float
    apr: float
    product_id: str
    expiry_date: datetime
    days_remaining: int


@dataclass
class Portfolio:
    spot: Dict[str, SpotBalance] = field(default_factory=dict)
    flexible: List[FlexiblePosition] = field(default_factory=list)
    locked: List[LockedPosition] = field(default_factory=list)

    def total_value(self) -> float:
        total = 0.0
        for b in self.spot.values():
            total += b.total
        for p in self.flexible:
            total += p.amount
        for p in self.locked:
            total += p.amount
        return total

    def liquid_value(self) -> float:
        """Spot free + flexible earn (rescatable de inmediato)."""
        total = sum(b.free for b in self.spot.values())
        total += sum(p.amount for p in self.flexible)
        return total

    def flat_balances(self) -> Dict[str, float]:
        """Dict plano para comparar con estado anterior."""
        result: Dict[str, float] = {}
        for asset, b in self.spot.items():
            result[f"{asset}_spot"] = b.total
        for p in self.flexible:
            result[f"{p.asset}_flexible"] = p.amount
        for p in self.locked:
            result[f"{p.asset}_locked_{p.product_id}"] = p.amount
        return result


@dataclass
class EarnProduct:
    asset: str
    product_id: str
    apr: float
    min_purchase: float
    is_flexible: bool
    duration_days: int = 0   # solo para locked


class BinanceClient:
    def __init__(self, api_key: str, api_secret: str, testnet: bool = False):
        self._client = Client(api_key, api_secret, testnet=testnet)

    def get_portfolio(self, assets: List[str]) -> Portfolio:
        portfolio = Portfolio()
        portfolio.spot = self._get_spot_balances(assets)
        portfolio.flexible = self._get_flexible_positions(assets)
        portfolio.locked = self._get_locked_positions(assets)
        return portfolio

    def _get_spot_balances(self, assets: List[str]) -> Dict[str, SpotBalance]:
        try:
            account = self._client.get_account()
            balances = {}
            for b in account["balances"]:
                if b["asset"] in assets:
                    free = float(b["free"])
                    locked = float(b["locked"])
                    if free > 0 or locked > 0:
                        balances[b["asset"]] = SpotBalance(
                            asset=b["asset"],
                            free=free,
                            locked=locked,
                        )
            return balances
        except BinanceAPIException as e:
            logger.error("Error obteniendo saldos spot: %s", e)
            raise

    def _get_flexible_positions(self, assets: List[str]) -> List[FlexiblePosition]:
        positions = []
        try:
            for asset in assets:
                resp = self._client.get_flexible_product_position(asset=asset)
                for item in resp.get("rows", []):
                    amount = float(item.get("totalAmount", 0))
                    if amount <= 0:
                        continue
                    apr = float(item.get("latestAnnualPercentageRate", 0)) * 100
                    positions.append(FlexiblePosition(
                        asset=item["asset"],
                        amount=amount,
                        apr=apr,
                        product_id=item.get("productId", ""),
                    ))
        except BinanceAPIException as e:
            logger.error("Error obteniendo posiciones flexible: %s", e)
            raise
        return positions

    def _get_locked_positions(self, assets: List[str]) -> List[LockedPosition]:
        positions = []
        try:
            for asset in assets:
                resp = self._client.get_locked_product_position(asset=asset)
                for item in resp.get("rows", []):
                    amount = float(item.get("amount", 0))
                    if amount <= 0:
                        continue
                    apr = float(item.get("apy", 0)) * 100
                    expiry_ts = int(item.get("deliverDate", 0)) / 1000
                    expiry_dt = datetime.fromtimestamp(expiry_ts) if expiry_ts else datetime.now()
                    days_remaining = max(0, (expiry_dt - datetime.now()).days)
                    positions.append(LockedPosition(
                        asset=item["asset"],
                        amount=amount,
                        apr=apr,
                        product_id=item.get("positionId", ""),
                        expiry_date=expiry_dt,
                        days_remaining=days_remaining,
                    ))
        except BinanceAPIException as e:
            logger.error("Error obteniendo posiciones locked: %s", e)
            raise
        return positions

    def get_available_flexible_products(self, assets: List[str]) -> List[EarnProduct]:
        products = []
        try:
            for asset in assets:
                resp = self._client.get_flexible_product_list(asset=asset, status="SUBSCRIBABLE")
                for item in resp.get("rows", []):
                    apr = float(item.get("latestAnnualPercentageRate", 0)) * 100
                    products.append(EarnProduct(
                        asset=item["asset"],
                        product_id=item["productId"],
                        apr=apr,
                        min_purchase=float(item.get("minPurchaseAmount", 0)),
                        is_flexible=True,
                    ))
        except BinanceAPIException as e:
            logger.error("Error obteniendo productos flexible: %s", e)
            raise
        return products

    def get_available_locked_products(self, assets: List[str]) -> List[EarnProduct]:
        products = []
        try:
            for asset in assets:
                resp = self._client.get_locked_product_list(asset=asset)
                for item in resp.get("rows", []):
                    apr = float(item.get("apy", 0)) * 100
                    duration = int(item.get("duration", 0))
                    products.append(EarnProduct(
                        asset=item["asset"],
                        product_id=item["projectId"],
                        apr=apr,
                        min_purchase=float(item.get("minPurchaseAmount", 0)),
                        is_flexible=False,
                        duration_days=duration,
                    ))
        except BinanceAPIException as e:
            logger.error("Error obteniendo productos locked: %s", e)
            raise
        return products

    def subscribe_flexible(self, product_id: str, amount: float) -> bool:
        try:
            self._client.purchase_flexible_product(productId=product_id, amount=amount)
            return True
        except BinanceAPIException as e:
            logger.error("Error suscribiendo a flexible %s: %s", product_id, e)
            return False

    def redeem_flexible(self, product_id: str, amount: float) -> bool:
        try:
            self._client.redeem_flexible_product(productId=product_id, amount=amount, type="FAST")
            return True
        except BinanceAPIException as e:
            logger.error("Error rescatando flexible %s: %s", product_id, e)
            return False

    def subscribe_locked(self, product_id: str, amount: float) -> bool:
        try:
            self._client.purchase_locked_product(projectId=product_id, amount=amount)
            return True
        except BinanceAPIException as e:
            logger.error("Error suscribiendo a locked %s: %s", product_id, e)
            return False
