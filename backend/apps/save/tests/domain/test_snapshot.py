import pytest

from save.domain.snapshot import InvalidSnapshot, initial_state, parse_snapshot
from save.tests.support import state


def test_클라이언트_세이브에서_검증_필드만_읽는다():
    s = parse_snapshot(state(stage=7, highestStage=9, gold=123.5, levels={"attack": 3, "teleport": 9}, totalKills=80))
    assert (s.stage, s.highest_stage, s.gold, s.total_kills) == (7, 9, 123.5, 80)
    assert s.levels == {"attack": 3}  # 모르는 업그레이드는 버린다


def test_초기_세이브는_스냅샷으로_읽힌다():
    s = parse_snapshot(initial_state())
    assert s.stage == 1 and s.gold == 0 and s.levels == {}


@pytest.mark.parametrize(
    "bad",
    [
        {"gold": 1},  # stage 없음
        state(stage=0),
        state(stage=5, highestStage=3),
        state(gold=-1),
        state(levels={"attack": -2}),
        state(levels="x"),
        state(stage="abc"),
    ],
)
def test_깨진_세이브는_거부한다(bad):
    with pytest.raises(InvalidSnapshot):
        parse_snapshot(bad)
