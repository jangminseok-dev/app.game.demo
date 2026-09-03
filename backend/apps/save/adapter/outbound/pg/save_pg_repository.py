from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from save.adapter.outbound.orm.save_orm import SaveOrm
from save.app.ports.output.save_repository import SaveRecord, SaveRepository


def _to_record(row: SaveOrm) -> SaveRecord:
    return SaveRecord(player_id=row.player_id, state=row.state, synced_at=row.synced_at)


class SavePgRepository(SaveRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def find(self, player_id: int) -> SaveRecord | None:
        row = await self._session.scalar(select(SaveOrm).where(SaveOrm.player_id == player_id))
        return _to_record(row) if row else None

    async def upsert(self, player_id: int, state: dict[str, Any], synced_at: datetime) -> SaveRecord:
        row = await self._session.scalar(select(SaveOrm).where(SaveOrm.player_id == player_id))
        if row is None:
            row = SaveOrm(player_id=player_id, state=state, synced_at=synced_at)
            self._session.add(row)
        else:
            row.state = state
            row.synced_at = synced_at
        await self._session.commit()
        await self._session.refresh(row)
        return _to_record(row)
