from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class PlayerRecord:
    id: int
    device_id: str
    created_at: datetime


class PlayerRepository(ABC):
    @abstractmethod
    async def find_by_device_id(self, device_id: str) -> PlayerRecord | None: ...

    @abstractmethod
    async def create(self, device_id: str) -> PlayerRecord:
        """같은 device_id가 이미 있으면 그 계정을 돌려준다(동시 요청 안전)."""
        ...
