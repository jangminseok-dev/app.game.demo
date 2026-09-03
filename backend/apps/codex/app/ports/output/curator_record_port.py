from __future__ import annotations

from abc import ABC, abstractmethod


class CuratorRecordPort(ABC):
    """도감 (codex)의 활동 기록 아웃바운드 포트."""

    @abstractmethod
    async def record(self, subject: str, note: str) -> None: ...
