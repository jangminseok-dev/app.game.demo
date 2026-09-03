from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from hub.app.ports.output.balance_port import BalancePort
from hub.dependencies.balance_provider import get_balance_port
from save.adapter.outbound.log_sync_rejection_adapter import LogSyncRejectionAdapter
from save.adapter.outbound.pg.save_pg_repository import SavePgRepository
from save.app.ports.input.sync_use_case import SyncUseCase
from save.app.use_cases.sync_interactor import SyncInteractor


def get_sync_use_case(
    db: AsyncSession = Depends(get_db),
    balance: BalancePort = Depends(get_balance_port),
) -> SyncUseCase:
    return SyncInteractor(
        saves=SavePgRepository(session=db), balance=balance, rejections=LogSyncRejectionAdapter()
    )
