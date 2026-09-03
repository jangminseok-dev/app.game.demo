from __future__ import annotations

from masterdata.adapter.outbound.file.file_balance_source_adapter import FileBalanceSourceAdapter
from masterdata.adapter.outbound.log_almanac_record_adapter import LogAlmanacRecordAdapter
from masterdata.app.ports.input.almanac_use_case import AlmanacUseCase
from masterdata.app.use_cases.almanac_interactor import AlmanacInteractor


def get_almanac_use_case() -> AlmanacUseCase:
    return AlmanacInteractor(record=LogAlmanacRecordAdapter(), source=FileBalanceSourceAdapter())
