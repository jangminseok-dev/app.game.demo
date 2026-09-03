from __future__ import annotations

from abc import ABC, abstractmethod

from hub.app.dtos.monster_dto import MonsterCatalog


class MonsterSourcePort(ABC):
    """몬스터·지역 마스터 데이터 저장소 포트. 지금은 리포지토리 안 JSON 파일."""

    @abstractmethod
    async def load(self) -> MonsterCatalog: ...
