from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from codex.adapter.outbound.orm.codex_entry_orm import CodexEntryOrm
from codex.app.ports.output.codex_repository import CodexRepository


class CodexPgRepository(CodexRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def stars_by_monster(self, player_id: int) -> dict[int, int]:
        rows = await self._session.scalars(select(CodexEntryOrm).where(CodexEntryOrm.player_id == player_id))
        return {r.monster_id: r.stars for r in rows}

    async def set_stars(self, player_id: int, stars_by_monster: dict[int, int]) -> None:
        if not stars_by_monster:
            return
        rows = await self._session.scalars(
            select(CodexEntryOrm).where(
                CodexEntryOrm.player_id == player_id,
                CodexEntryOrm.monster_id.in_(list(stars_by_monster)),
            )
        )
        existing = {r.monster_id: r for r in rows}
        for monster_id, stars in stars_by_monster.items():
            row = existing.get(monster_id)
            if row is None:
                self._session.add(CodexEntryOrm(player_id=player_id, monster_id=monster_id, stars=stars))
            else:
                row.stars = stars
        await self._session.commit()
