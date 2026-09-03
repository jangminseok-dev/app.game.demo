from __future__ import annotations

from hub.app.dtos.monster_dto import MonsterCatalog
from hub.app.ports.output.monster_catalog_port import MonsterCatalogPort
from masterdata.app.ports.output.monster_source_port import MonsterSourcePort


class MonsterCatalogGateway(MonsterCatalogPort):
    """허브 `MonsterCatalogPort` 구현 — codex·save가 몬스터 표를 받아 가는 창구."""

    def __init__(self, source: MonsterSourcePort) -> None:
        self._source = source

    async def get_catalog(self) -> MonsterCatalog:
        return await self._source.load()
