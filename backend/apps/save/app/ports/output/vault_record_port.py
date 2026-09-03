from __future__ import annotations

from abc import ABC, abstractmethod


class VaultRecordPort(ABC):
    """세이브 (save)의 활동 기록 아웃바운드 포트."""

    @abstractmethod
    async def record(self, subject: str, note: str) -> None: ...
