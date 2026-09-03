from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from codex.adapter.outbound.gateways.codex_gateway import CodexGateway
from codex.adapter.outbound.pg.codex_pg_repository import CodexPgRepository
from core.database import get_db
from hub.app.ports.output.balance_port import BalancePort
from hub.app.ports.output.codex_port import CodexPort
from hub.app.ports.output.monster_catalog_port import MonsterCatalogPort
from hub.dependencies.balance_provider import get_balance_port
from hub.dependencies.monster_catalog_provider import get_monster_catalog_port


def get_codex_gateway(
    db: AsyncSession = Depends(get_db),
    catalog: MonsterCatalogPort = Depends(get_monster_catalog_port),
    balance: BalancePort = Depends(get_balance_port),
) -> CodexPort:
    """허브 `get_codex_port`에 main.py가 바인딩한다."""
    return CodexGateway(entries=CodexPgRepository(session=db), catalog=catalog, balance=balance)
