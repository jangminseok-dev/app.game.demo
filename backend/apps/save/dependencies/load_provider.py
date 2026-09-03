from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from hub.app.ports.output.balance_port import BalancePort
from hub.app.ports.output.codex_port import CodexPort
from hub.dependencies.balance_provider import get_balance_port
from hub.dependencies.codex_provider import get_codex_port
from save.adapter.outbound.pg.save_pg_repository import SavePgRepository
from save.app.ports.input.load_use_case import LoadUseCase
from save.app.use_cases.load_interactor import LoadInteractor


def get_load_use_case(
    db: AsyncSession = Depends(get_db),
    balance: BalancePort = Depends(get_balance_port),
    codex: CodexPort = Depends(get_codex_port),
) -> LoadUseCase:
    return LoadInteractor(saves=SavePgRepository(session=db), balance=balance, codex=codex)
