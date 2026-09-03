from __future__ import annotations

from abc import ABC, abstractmethod


class RegistrarRecordPort(ABC):
    """인증 (auth)의 활동 기록 아웃바운드 포트."""

    @abstractmethod
    async def record(self, subject: str, note: str) -> None: ...
