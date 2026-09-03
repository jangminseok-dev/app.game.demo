from __future__ import annotations

from fastapi import Depends

from codex.adapter.outbound.log_curator_record_adapter import LogCuratorRecordAdapter
from codex.app.ports.input.curator_use_case import CuratorUseCase
from codex.app.use_cases.curator_interactor import CuratorInteractor
from hub.app.ports.output.balance_port import BalancePort
from hub.app.ports.output.monster_catalog_port import MonsterCatalogPort
from hub.dependencies.balance_provider import get_balance_port
from hub.dependencies.monster_catalog_provider import get_monster_catalog_port


def get_curator_use_case(
    catalog: MonsterCatalogPort = Depends(get_monster_catalog_port),
    balance: BalancePort = Depends(get_balance_port),
) -> CuratorUseCase:
    return CuratorInteractor(record=LogCuratorRecordAdapter(), catalog=catalog, balance=balance)
