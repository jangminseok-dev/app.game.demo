from __future__ import annotations

from abc import ABC, abstractmethod

from masterdata.app.dtos.bestiary_dto import BestiaryQuery, BestiaryResponse


class BestiaryUseCase(ABC):
    """몬스터·지역 표 서빙 — 클라이언트가 시작 시 받아 캐시한다 (GAME_DESIGN 6장·13장)."""

    @abstractmethod
    async def fetch(self, query: BestiaryQuery) -> BestiaryResponse: ...
