from __future__ import annotations

from dataclasses import asdict

from masterdata.app.dtos.balance_dto import BalanceQuery, BalanceResponse
from masterdata.app.ports.input.balance_use_case import BalanceUseCase
from masterdata.app.ports.output.balance_source_port import BalanceSourcePort


class BalanceInteractor(BalanceUseCase):
    def __init__(self, source: BalanceSourcePort) -> None:
        self._source = source

    async def fetch(self, query: BalanceQuery) -> BalanceResponse:
        record = await self._source.load()
        return BalanceResponse(
            unchanged=query.client_version == record.version,
            **asdict(record),
        )
