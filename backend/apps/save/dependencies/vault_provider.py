from __future__ import annotations

from fastapi import Depends

from hub.app.ports.output.balance_port import BalancePort
from hub.dependencies.balance_provider import get_balance_port
from save.adapter.outbound.log_vault_record_adapter import LogVaultRecordAdapter
from save.app.ports.input.vault_use_case import VaultUseCase
from save.app.use_cases.vault_interactor import VaultInteractor


def get_vault_use_case(balance: BalancePort = Depends(get_balance_port)) -> VaultUseCase:
    return VaultInteractor(record=LogVaultRecordAdapter(), balance=balance)
