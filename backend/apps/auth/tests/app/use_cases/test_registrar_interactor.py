from auth.app.dtos.registrar_dto import RegistrarQuery
from auth.app.use_cases.registrar_interactor import RegistrarInteractor


class _StubRecord:
    def __init__(self):
        self.records = []

    async def record(self, subject, note):
        self.records.append((subject, note))


async def test_자기소개는_실기능과_제약을_서술하고_기록을_남긴다():
    record = _StubRecord()
    r = await RegistrarInteractor(record=record, access_token_ttl_seconds=3600).introduce_myself(
        RegistrarQuery(id=1, name="인증 (auth)")
    )
    assert r.id == 1
    assert record.records[0][0] == "introduce_myself"
    assert "POST /auth/guest" in r.introduction
    assert "소셜 연동은 아직 제공하지 않습니다" in r.introduction
    assert r.access_token_ttl_seconds == 3600
