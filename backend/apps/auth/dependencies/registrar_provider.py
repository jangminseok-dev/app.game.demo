from __future__ import annotations

from auth.adapter.outbound.log_registrar_record_adapter import LogRegistrarRecordAdapter
from auth.app.ports.input.registrar_use_case import RegistrarUseCase
from auth.app.use_cases.registrar_interactor import RegistrarInteractor
from core.config import JWT_ACCESS_TTL_SECONDS


def get_registrar_use_case() -> RegistrarUseCase:
    return RegistrarInteractor(
        record=LogRegistrarRecordAdapter(), access_token_ttl_seconds=JWT_ACCESS_TTL_SECONDS
    )
