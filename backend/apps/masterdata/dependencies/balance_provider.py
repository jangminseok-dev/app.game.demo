from __future__ import annotations

from hub.app.ports.output.balance_port import BalancePort
from masterdata.adapter.outbound.file.file_balance_source_adapter import FileBalanceSourceAdapter
from masterdata.adapter.outbound.gateways.balance_gateway import BalanceGateway
from masterdata.app.ports.input.balance_use_case import BalanceUseCase
from masterdata.app.use_cases.balance_interactor import BalanceInteractor


def get_balance_use_case() -> BalanceUseCase:
    return BalanceInteractor(source=FileBalanceSourceAdapter())


def get_balance_gateway() -> BalancePort:
    """허브 `get_balance_port`에 main.py가 바인딩한다."""
    return BalanceGateway(source=FileBalanceSourceAdapter())
