from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from auth.adapter.outbound.orm.player_orm import PlayerOrm
from auth.app.ports.output.player_repository import PlayerRecord, PlayerRepository


def _to_record(row: PlayerOrm) -> PlayerRecord:
    return PlayerRecord(id=row.id, device_id=row.device_id, created_at=row.created_at)


class PlayerPgRepository(PlayerRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def find_by_device_id(self, device_id: str) -> PlayerRecord | None:
        row = await self._session.scalar(select(PlayerOrm).where(PlayerOrm.device_id == device_id))
        return _to_record(row) if row else None

    async def create(self, device_id: str) -> PlayerRecord:
        row = PlayerOrm(device_id=device_id)
        self._session.add(row)
        try:
            await self._session.commit()
        except IntegrityError:
            # 같은 기기의 동시 요청 — unique 제약이 막았으니 이미 만들어진 쪽을 돌려준다.
            await self._session.rollback()
            existing = await self.find_by_device_id(device_id)
            assert existing is not None
            return existing
        await self._session.refresh(row)
        return _to_record(row)
