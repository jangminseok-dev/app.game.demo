from save.app.dtos.vault_dto import VaultQuery
from save.app.use_cases.vault_interactor import VaultInteractor
from save.tests.support import StubBalance


class _StubRecord:
    def __init__(self):
        self.records = []

    async def record(self, subject, note):
        self.records.append((subject, note))


async def test_자기소개는_실기능과_제약을_서술하고_기록을_남긴다():
    record = _StubRecord()
    r = await VaultInteractor(record=record, balance=StubBalance()).introduce_myself(
        VaultQuery(id=2, name="세이브 (save)")
    )
    assert r.id == 2
    assert record.records[0][0] == "introduce_myself"
    assert "GET /save" in r.introduction and "PUT /save" in r.introduction
    assert "전투 판정은 하지 않습니다" in r.introduction
    assert r.offline_cap_seconds == 8 * 3600
