from masterdata.app.dtos.almanac_dto import AlmanacQuery
from masterdata.app.use_cases.almanac_interactor import AlmanacInteractor
from masterdata.tests.app.use_cases.test_balance_interactor import RECORD


class _StubRecord:
    def __init__(self):
        self.records = []

    async def record(self, subject, note):
        self.records.append((subject, note))


class _StubSource:
    async def load(self):
        return RECORD


async def test_자기소개는_실기능을_서술하고_기록을_남긴다():
    record = _StubRecord()
    r = await AlmanacInteractor(record=record, source=_StubSource()).introduce_myself(
        AlmanacQuery(id=3, name="마스터데이터 (masterdata)")
    )
    assert r.id == 3
    assert record.records[0][0] == "introduce_myself"
    assert "/masterdata/balance" in r.introduction
    assert "계수를 바꾸는 API는 없습니다" in r.introduction
    assert r.balance_version == 3
