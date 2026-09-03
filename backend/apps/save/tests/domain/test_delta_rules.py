from save.domain.balance.formulas import upgrade_cost
from save.domain.snapshot import parse_snapshot
from save.domain.validation import delta_rules
from save.tests.support import BALANCE, state


def _v(prev, new, elapsed):
    return delta_rules.validate(parse_snapshot(prev), parse_snapshot(new), elapsed, BALANCE)


def test_정직한_30초_플레이는_통과한다():
    # 30초 동안 속도 1.0으로 약 15마리, 골드 5.75×15 ≈ 86, 공격력 2레벨 구매(10 + 10.9)
    prev = state()
    new = state(gold=86 - 10 - 10.9, levels={"attack": 2}, totalKills=15, stage=2, highestStage=2)
    assert _v(prev, new, 30) is None


def test_레벨이_줄면_거부():
    v = _v(state(levels={"attack": 5}), state(levels={"attack": 4}), 30)
    assert v.rule == "level_decreased"


def test_최고_스테이지나_누적_처치가_줄면_거부():
    assert _v(state(highestStage=10, stage=10), state(highestStage=9, stage=9), 30).rule == "highest_stage_decreased"
    assert _v(state(totalKills=50), state(totalKills=49), 30).rule == "kills_decreased"


def test_경과_시간보다_많은_처치는_거부():
    # 30초에 속도 1.0이면 상한 30×1.5+1 = 46마리
    assert _v(state(), state(totalKills=46), 30) is None
    assert _v(state(), state(totalKills=47), 30).rule == "too_many_kills"


def test_벌_수_없는_골드는_거부():
    # 처치 0인데 골드가 생기면 안 된다
    v = _v(state(), state(gold=1000), 30)
    assert v.rule == "gold_conservation"


def test_구매한_업그레이드는_골드_보존에_반영된다():
    # 5마리 처치 최대 벌이 = 5 × 보스보상(스테이지1: 57.5) = 287.5
    cost = upgrade_cost("attack", 0, BALANCE) + upgrade_cost("attack", 1, BALANCE)
    ok = state(gold=287.5 - cost, levels={"attack": 2}, totalKills=5)
    assert _v(state(), ok, 30) is None
    too_much = state(gold=287.5 - cost + 1, levels={"attack": 2}, totalKills=5)
    assert _v(state(), too_much, 30).rule == "gold_conservation"


def test_아주_짧은_간격도_최소_5초는_인정한다():
    assert _v(state(), state(totalKills=8), 0.1) is None
