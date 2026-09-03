from __future__ import annotations

from abc import ABC, abstractmethod

from codex.domain.capture import CodexRow


class CodexRepository(ABC):
    @abstractmethod
    async def rows_by_monster(self, player_id: int) -> dict[int, CodexRow]:
        """성급 0이라도 천장 카운트가 있는 행은 포함한다."""
        ...

    @abstractmethod
    async def save_rows(self, player_id: int, rows: dict[int, CodexRow]) -> None:
        """바뀐 몬스터만 넘긴다. 없으면 만들고 있으면 덮어쓴다."""
        ...
