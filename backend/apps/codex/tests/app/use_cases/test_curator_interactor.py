from codex.app.dtos.curator_dto import CuratorQuery
from codex.app.use_cases.curator_interactor import CuratorInteractor
from codex.tests.support import StubBalance, StubCatalog


class _StubRecord:
    def __init__(self):
        self.records = []

    async def record(self, subject, note):
        self.records.append((subject, note))


async def test_자기소개는_판정_규칙과_제약을_서술하고_기록을_남긴다():
    record = _StubRecord()
    r = await CuratorInteractor(record=record, catalog=StubCatalog(), balance=StubBalance()).introduce_myself(
        CuratorQuery(id=4, name="도감 (codex)")
    )
    assert record.records[0][0] == "introduce_myself"
    assert "클라이언트가 보낸 포획 결과는 믿지 않습니다" in r.introduction
    assert "PUT /save" in r.introduction
    assert r.monster_count == 4 and r.max_stars == 5
