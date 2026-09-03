from __future__ import annotations

from codex.app.dtos.curator_dto import CuratorQuery, CuratorResponse
from codex.app.ports.input.curator_use_case import CuratorUseCase
from codex.app.ports.output.curator_record_port import CuratorRecordPort
from hub.app.ports.output.balance_port import BalancePort
from hub.app.ports.output.monster_catalog_port import MonsterCatalogPort

_INTRODUCTION = (
    "플레이어의 몬스터 도감을 관리합니다. "
    "공개 엔드포인트는 이 자기소개뿐입니다 — 도감 갱신은 PUT /save(세이브 동기화)에 실린 처치 보고를 "
    "받아 서버가 포획 확률을 굴리며, 결과는 그 응답의 captures로 돌아갑니다. "
    "도감 목록은 GET /save 응답의 codex에 실립니다. "
    "포획 확률 = 플레이어 기본 포획률 × 몬스터 희귀도(× 보스 배율). 마지막 포획 이후 처치가 천장(희귀도 1.0 기준 "
    "capture_pity_kills ÷ 희귀도)에 닿으면 확정 포획합니다. 클라이언트가 보낸 포획 결과는 믿지 않습니다. "
    "도감은 전생해도 초기화되지 않습니다."
)


class CuratorInteractor(CuratorUseCase):
    def __init__(self, record: CuratorRecordPort, catalog: MonsterCatalogPort, balance: BalancePort) -> None:
        self._record = record
        self._catalog = catalog
        self._balance = balance

    async def introduce_myself(self, query: CuratorQuery) -> CuratorResponse:
        await self._record.record(subject="introduce_myself", note=f"{query.name} 자기소개 관찰")
        catalog = await self._catalog.get_catalog()
        b = await self._balance.get_balance()
        return CuratorResponse(
            id=query.id,
            name=query.name,
            introduction=_INTRODUCTION,
            monster_count=len(catalog.monsters),
            max_stars=b.max_stars,
        )
