from __future__ import annotations

from abc import ABC, abstractmethod

from hub.app.dtos.monster_dto import MonsterCatalog


class MonsterCatalogPort(ABC):
    """몬스터·지역 마스터 데이터 협력 — masterdata(구현)와 codex·save(소비)를 잇는다."""

    @abstractmethod
    async def get_catalog(self) -> MonsterCatalog: ...
