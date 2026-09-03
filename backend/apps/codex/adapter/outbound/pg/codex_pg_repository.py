from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from codex.adapter.outbound.orm.codex_entry_orm import CodexEntryOrm
from codex.app.ports.output.codex_repository import CodexRepository
from codex.domain.capture import CodexRow


class CodexPgRepository(CodexRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def rows_by_monster(self, player_id: int) -> dict[int, CodexRow]:
        rows = await self._session.scalars(select(CodexEntryOrm).where(CodexEntryOrm.player_id == player_id))
        return {r.monster_id: CodexRow(stars=r.stars, pity_kills=r.pity_kills) for r in rows}

    async def save_rows(self, player_id: int, rows: dict[int, CodexRow]) -> None:
        if not rows:
            return
        existing_rows = await self._session.scalars(
            select(CodexEntryOrm).where(
                CodexEntryOrm.player_id == player_id,
                CodexEntryOrm.monster_id.in_(list(rows)),
            )
        )
        existing = {r.monster_id: r for r in existing_rows}
        for monster_id, row in rows.items():
            orm = existing.get(monster_id)
            if orm is None:
                self._session.add(
                    CodexEntryOrm(player_id=player_id, monster_id=monster_id, stars=row.stars, pity_kills=row.pity_kills)
                )
            else:
                orm.stars = row.stars
                orm.pity_kills = row.pity_kills
        await self._session.commit()
