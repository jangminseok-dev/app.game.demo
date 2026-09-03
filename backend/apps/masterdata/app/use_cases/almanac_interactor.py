from __future__ import annotations

from masterdata.app.dtos.almanac_dto import AlmanacQuery, AlmanacResponse
from masterdata.app.ports.input.almanac_use_case import AlmanacUseCase
from masterdata.app.ports.output.almanac_record_port import AlmanacRecordPort
from masterdata.app.ports.output.balance_source_port import BalanceSourcePort

_INTRODUCTION = (
    "게임 밸런스 계수를 제공합니다. "
    "GET /masterdata/balance — 몬스터 HP·골드·업그레이드 비용 성장률, 보스 제한시간, "
    "오프라인 보상 상한·효율을 버전과 함께 냅니다. "
    "클라이언트는 이 계수를 캐시하고 버전이 바뀔 때만 다시 받습니다. "
    "몬스터·스테이지 테이블은 아직 제공하지 않습니다(도감 단계에서 추가). "
    "계수를 바꾸는 API는 없습니다 — 편집은 배포로만 이루어집니다."
)


class AlmanacInteractor(AlmanacUseCase):
    def __init__(self, record: AlmanacRecordPort, source: BalanceSourcePort) -> None:
        self._record = record
        self._source = source

    async def introduce_myself(self, query: AlmanacQuery) -> AlmanacResponse:
        await self._record.record(subject="introduce_myself", note=f"{query.name} 자기소개 관찰")
        balance = await self._source.load()
        return AlmanacResponse(
            id=query.id,
            name=query.name,
            introduction=_INTRODUCTION,
            balance_version=balance.version,
        )
