from __future__ import annotations

from auth.app.dtos.registrar_dto import RegistrarQuery, RegistrarResponse
from auth.app.ports.input.registrar_use_case import RegistrarUseCase
from auth.app.ports.output.registrar_record_port import RegistrarRecordPort

_INTRODUCTION = (
    "플레이어 계정을 관리합니다. "
    "POST /auth/guest — 기기 식별자로 게스트 계정을 만들거나 찾고 액세스 토큰(JWT)을 냅니다. "
    "로그인 화면 없이 바로 시작하는 용도이며, 기기를 바꾸면 계정을 잃습니다 "
    "(소셜 연동은 아직 제공하지 않습니다). "
    "리프레시 토큰은 없고 만료되면 /auth/guest를 다시 부릅니다. "
    "비밀번호·이메일은 저장하지 않습니다."
)


class RegistrarInteractor(RegistrarUseCase):
    def __init__(self, record: RegistrarRecordPort, access_token_ttl_seconds: int) -> None:
        self._record = record
        self._ttl = access_token_ttl_seconds

    async def introduce_myself(self, query: RegistrarQuery) -> RegistrarResponse:
        await self._record.record(subject="introduce_myself", note=f"{query.name} 자기소개 관찰")
        return RegistrarResponse(
            id=query.id,
            name=query.name,
            introduction=_INTRODUCTION,
            access_token_ttl_seconds=self._ttl,
        )
