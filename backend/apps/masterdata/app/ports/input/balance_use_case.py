from __future__ import annotations

from abc import ABC, abstractmethod

from masterdata.app.dtos.balance_dto import BalanceQuery, BalanceResponse


class BalanceUseCase(ABC):
    """밸런스 계수 서빙 — 클라이언트가 시작 시 받아 캐시한다 (GAME_DESIGN 4장·13장)."""

    @abstractmethod
    async def fetch(self, query: BalanceQuery) -> BalanceResponse: ...
