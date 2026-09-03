from __future__ import annotations

from abc import ABC, abstractmethod

from save.app.dtos.sync_dto import SyncCommand, SyncResponse


class SyncUseCase(ABC):
    """클라이언트 → 서버 동기화 (GAME_DESIGN 12장). 30초 주기·백그라운드 진입 시 호출.

    델타 검증을 통과하면 저장하고, 실패하면 서버 상태로 롤백해 돌려준다.
    """

    @abstractmethod
    async def sync(self, command: SyncCommand) -> SyncResponse: ...
