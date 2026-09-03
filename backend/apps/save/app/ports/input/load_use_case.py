from __future__ import annotations

from abc import ABC, abstractmethod

from save.app.dtos.load_dto import LoadQuery, LoadResponse


class LoadUseCase(ABC):
    """세이브 복원 + 오프라인 보상 지급 (GAME_DESIGN 8장·12장). 앱 시작 시 한 번 부른다."""

    @abstractmethod
    async def load(self, query: LoadQuery) -> LoadResponse: ...
