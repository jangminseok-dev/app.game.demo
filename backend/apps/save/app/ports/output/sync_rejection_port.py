from __future__ import annotations

from abc import ABC, abstractmethod


class SyncRejectionPort(ABC):
    """델타 검증 위반 기록 — 반복 위반 계정을 랭킹에서 빼는 근거가 된다 (GAME_DESIGN 12장)."""

    @abstractmethod
    async def record(self, player_id: int, rule: str, detail: str) -> None: ...
