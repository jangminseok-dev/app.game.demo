from datetime import timedelta

from save.app.dtos.load_dto import LoadQuery
from save.app.ports.output.save_repository import SaveRecord
from save.app.use_cases.load_interactor import LoadInteractor
from save.tests.support import T0, CodexEntry, Passives, StubBalance, StubCodex, StubSaves, state


async def test_세이브가_없으면_초기_세이브를_만든다():
    saves = StubSaves()
    r = await LoadInteractor(saves=saves, balance=StubBalance(), codex=StubCodex()).load(LoadQuery(player_id=1, now=T0))
    assert r.created is True
    assert r.state["stage"] == 1 and r.state["gold"] == 0
    assert r.synced_at == T0
    assert r.offline_gold == 0
    assert saves.upserts == 1


async def test_오래_비웠으면_보상을_더하고_동기화_시각을_옮긴다():
    saves = StubSaves(SaveRecord(player_id=1, state=state(stage=3, gold=100), synced_at=T0))
    now = T0 + timedelta(hours=2)
    r = await LoadInteractor(saves=saves, balance=StubBalance(), codex=StubCodex()).load(LoadQuery(player_id=1, now=now))
    assert r.created is False
    assert r.offline_gold > 0
    assert r.offline_elapsed_seconds == 7200
    assert r.state["gold"] == 100 + r.offline_gold
    assert r.synced_at == now


async def test_보상은_한_번만_받는다():
    saves = StubSaves(SaveRecord(player_id=1, state=state(gold=100), synced_at=T0))
    sut = LoadInteractor(saves=saves, balance=StubBalance(), codex=StubCodex())
    now = T0 + timedelta(hours=1)
    first = await sut.load(LoadQuery(player_id=1, now=now))
    second = await sut.load(LoadQuery(player_id=1, now=now + timedelta(seconds=10)))
    assert first.offline_gold > 0
    assert second.offline_gold == 0
    assert second.state["gold"] == first.state["gold"]


async def test_방금_동기화했으면_그대로_돌려준다():
    saves = StubSaves(SaveRecord(player_id=1, state=state(gold=50), synced_at=T0))
    r = await LoadInteractor(saves=saves, balance=StubBalance(), codex=StubCodex()).load(
        LoadQuery(player_id=1, now=T0 + timedelta(seconds=20))
    )
    assert r.offline_gold == 0 and r.state["gold"] == 50
    assert saves.upserts == 0


async def test_도감_목록을_함께_주고_패시브가_보상에_반영된다():
    saves = StubSaves(SaveRecord(player_id=1, state=state(gold=0), synced_at=T0))
    plain = await LoadInteractor(saves=saves, balance=StubBalance(), codex=StubCodex()).load(
        LoadQuery(player_id=1, now=T0 + timedelta(hours=1))
    )
    saves2 = StubSaves(SaveRecord(player_id=1, state=state(gold=0), synced_at=T0))
    codex = StubCodex(passives=Passives(gold=50), entries=(CodexEntry(1, 2),))
    boosted = await LoadInteractor(saves=saves2, balance=StubBalance(), codex=codex).load(
        LoadQuery(player_id=1, now=T0 + timedelta(hours=1))
    )
    assert boosted.codex == (CodexEntry(1, 2),)
    assert abs(boosted.offline_gold - plain.offline_gold * 1.5) < 1e-6
