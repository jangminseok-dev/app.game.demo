from datetime import timedelta

import pytest

from save.app.dtos.sync_dto import SyncCommand
from save.app.ports.output.save_repository import SaveRecord
from save.app.use_cases.sync_interactor import NoSaveToSync, SyncInteractor
from save.domain.snapshot import InvalidSnapshot
from save.tests.support import T0, CaptureEvent, StubBalance, StubCodex, StubRejections, StubSaves, state


def _sut(saves, rejections=None, codex=None):
    return SyncInteractor(
        saves=saves, balance=StubBalance(), rejections=rejections or StubRejections(), codex=codex or StubCodex()
    )


async def test_정직한_변화는_저장한다():
    saves = StubSaves(SaveRecord(player_id=1, state=state(), synced_at=T0))
    new = state(gold=40, totalKills=10, levels={"attack": 1})
    r = await _sut(saves).sync(SyncCommand(player_id=1, state=new, now=T0 + timedelta(seconds=30)))
    assert r.accepted is True
    assert r.state == {**new, "killLog": {"normal": {}, "boss": {}}}
    assert r.synced_at == T0 + timedelta(seconds=30)
    assert r.captures == ()


async def test_조작된_변화는_거부하고_서버_상태로_돌려주며_기록한다():
    prev = state(gold=10)
    saves = StubSaves(SaveRecord(player_id=1, state=prev, synced_at=T0))
    rejections = StubRejections()
    r = await _sut(saves, rejections).sync(
        SyncCommand(player_id=1, state=state(gold=999_999), now=T0 + timedelta(seconds=30))
    )
    assert r.accepted is False
    assert r.rejected_rule == "gold_conservation"
    assert r.state == prev and r.synced_at == T0
    assert saves.upserts == 0
    assert rejections.records[0][:2] == (1, "gold_conservation")


async def test_세이브가_없으면_먼저_load하라고_알린다():
    with pytest.raises(NoSaveToSync):
        await _sut(StubSaves()).sync(SyncCommand(player_id=1, state=state(), now=T0))


async def test_형식이_깨진_상태는_거부한다():
    saves = StubSaves(SaveRecord(player_id=1, state=state(), synced_at=T0))
    with pytest.raises(InvalidSnapshot):
        await _sut(saves).sync(SyncCommand(player_id=1, state={"gold": 1}, now=T0))


async def test_처치_보고를_도감에_넘기고_포획_결과를_돌려주며_보고를_비운다():
    saves = StubSaves(SaveRecord(player_id=1, state=state(), synced_at=T0))
    codex = StubCodex(captures=(CaptureEvent(monster_id=1, stars=1, first=True),))
    new = state(gold=20, totalKills=5, killLog={"normal": {"1": 4}, "boss": {"1": 1}})
    r = await _sut(saves, codex=codex).sync(SyncCommand(player_id=1, state=new, now=T0 + timedelta(seconds=30)))
    assert r.accepted is True
    assert r.captures == (CaptureEvent(1, 1, True),)
    assert r.codex == ()
    player_id, report, rate = codex.reports[0]
    assert player_id == 1 and report.normal == {1: 4} and report.boss == {1: 1}
    assert abs(rate - 0.005) < 1e-9
    assert saves.record.state["killLog"] == {"normal": {}, "boss": {}}


async def test_보고한_처치가_누적_증가분보다_많으면_거부한다():
    saves = StubSaves(SaveRecord(player_id=1, state=state(), synced_at=T0))
    codex = StubCodex()
    new = state(gold=0, totalKills=3, killLog={"normal": {"1": 10}, "boss": {}})
    r = await _sut(saves, codex=codex).sync(SyncCommand(player_id=1, state=new, now=T0 + timedelta(seconds=30)))
    assert r.accepted is False and r.rejected_rule == "kill_report_exceeds_delta"
    assert codex.reports == []
