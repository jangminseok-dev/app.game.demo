from __future__ import annotations

from dataclasses import asdict

from hub.app.dtos.balance_dto import Balance
from hub.app.ports.output.balance_port import BalancePort
from masterdata.app.ports.output.balance_source_port import BalanceSourcePort


class BalanceGateway(BalancePort):
    """허브 `BalancePort` 구현 — 다른 스포크(save)가 계수를 받아 가는 창구."""

    def __init__(self, source: BalanceSourcePort) -> None:
        self._source = source

    async def get_balance(self) -> Balance:
        return Balance(**asdict(await self._source.load()))
