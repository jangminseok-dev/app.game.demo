from __future__ import annotations

from masterdata.app.dtos.bestiary_dto import BestiaryQuery, BestiaryResponse
from masterdata.app.ports.input.bestiary_use_case import BestiaryUseCase
from masterdata.app.ports.output.monster_source_port import MonsterSourcePort


class BestiaryInteractor(BestiaryUseCase):
    def __init__(self, source: MonsterSourcePort) -> None:
        self._source = source

    async def fetch(self, query: BestiaryQuery) -> BestiaryResponse:
        catalog = await self._source.load()
        return BestiaryResponse(unchanged=query.client_version == catalog.version, catalog=catalog)
