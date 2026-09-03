from __future__ import annotations

from hub.app.ports.output.balance_port import BalancePort
from save.app.dtos.vault_dto import VaultQuery, VaultResponse
from save.app.ports.input.vault_use_case import VaultUseCase
from save.app.ports.output.vault_record_port import VaultRecordPort

_INTRODUCTION = (
    "플레이어 세이브를 서버에 보관합니다. "
    "GET /save — 세이브를 돌려주고, 없으면 초기 세이브를 만듭니다. "
    "마지막 동기화 이후 경과한 시간(서버 시간)만큼 오프라인 골드를 더해 줍니다. "
    "PUT /save — 클라이언트 상태를 받아 델타 검증(레벨·처치 수·골드 보존 상한)을 통과하면 저장하고, "
    "실패하면 저장하지 않고 서버 상태를 돌려줍니다. "
    "전투 판정은 하지 않습니다 — 클라이언트가 돌린 결과를 검증만 합니다. "
    "동기화 응답에는 처치 보고로 굴린 포획 결과와 갱신된 도감(천장 진행 포함)이 실립니다. "
    "세이브 형식은 클라이언트 소유이며 서버는 검증에 필요한 필드만 읽습니다."
)


class VaultInteractor(VaultUseCase):
    def __init__(self, record: VaultRecordPort, balance: BalancePort) -> None:
        self._record = record
        self._balance = balance

    async def introduce_myself(self, query: VaultQuery) -> VaultResponse:
        await self._record.record(subject="introduce_myself", note=f"{query.name} 자기소개 관찰")
        b = await self._balance.get_balance()
        return VaultResponse(
            id=query.id,
            name=query.name,
            introduction=_INTRODUCTION,
            offline_cap_seconds=b.offline_cap_seconds,
            offline_efficiency=b.offline_efficiency,
        )
