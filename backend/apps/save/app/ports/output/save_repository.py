from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from typing import Any


@dataclass(frozen=True)
class SaveRecord:
    player_id: int
    state: dict[str, Any]
    synced_at: datetime


class SaveRepository(ABC):
    @abstractmethod
    async def find(self, player_id: int) -> SaveRecord | None: ...

    @abstractmethod
    async def upsert(self, player_id: int, state: dict[str, Any], synced_at: datetime) -> SaveRecord: ...
