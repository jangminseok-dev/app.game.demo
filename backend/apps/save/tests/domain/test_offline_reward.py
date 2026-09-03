from save.domain.balance import offline_reward
from save.domain.balance.formulas import gold_reward, monster_hp, stats_of
from save.domain.snapshot import parse_snapshot
from save.tests.support import BALANCE, state


def test_경과_시간_x_DPS만큼_잡은_몬스터의_골드를_50퍼센트로_준다():
    s = parse_snapshot(state(stage=5, levels={"goldGain": 4}))
    r = offline_reward.calculate(s, 3600, BALANCE)
    kills = stats_of(s, BALANCE).dps(BALANCE) * 3600 / monster_hp(5, BALANCE)
    assert r.gold == kills * gold_reward(5, BALANCE) * 1.2 * 0.5
    assert r.elapsed_seconds == 3600


def test_8시간_상한():
    s = parse_snapshot(state())
    assert offline_reward.calculate(s, 30 * 3600, BALANCE).gold == offline_reward.calculate(s, 8 * 3600, BALANCE).gold


def test_1분_미만이나_음수는_보상_없음():
    s = parse_snapshot(state())
    assert offline_reward.calculate(s, 59, BALANCE).paid is False
    assert offline_reward.calculate(s, -100, BALANCE).paid is False


def test_Flutter_구현과_같은_값():
    """flutter/test/domain/offline_reward_test.dart의 케이스와 교차 검증 — 공식이 갈리면 여기서 잡힌다."""
    s = parse_snapshot(state(stage=1))
    r = offline_reward.calculate(s, 3600, BALANCE)
    # 공격 10, 속도 1.0, 치명 5%×2배 → DPS 10.5 / HP 11.8 → 시간당 3203.4마리 × 5.75골드 × 0.5
    assert abs(r.gold - (10.5 * 3600 / 11.8) * 5.75 * 0.5) < 1e-6
