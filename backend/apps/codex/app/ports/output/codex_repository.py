from __future__ import annotations

from abc import ABC, abstractmethod


class CodexRepository(ABC):
    @abstractmethod
    async def stars_by_monster(self, player_id: int) -> dict[int, int]: ...

    @abstractmethod
    async def set_stars(self, player_id: int, stars_by_monster: dict[int, int]) -> None:
        """바뀐 몬스터만 넘긴다. 없으면 만들고 있으면 성급을 올린다."""
        ...
