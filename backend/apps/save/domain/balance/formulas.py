"""GAME_DESIGN 4장 공식 + 능력치 환산. Flutter `formulas.dart`·`upgrade.dart`와 1:1이다.

계수는 마스터데이터(허브 `Balance`)에서 오고 공식은 양쪽이 내장한다 — 계수 단일 소유 원칙.
도감 패시브(`Passives`, %)는 종류 안에서는 합산돼 오고, 여기서 능력치에 곱한다.
"""

from __future__ import annotations

from dataclasses import dataclass

from hub.app.dtos.balance_dto import Balance
from hub.app.dtos.codex_dto import Passives
from save.domain.snapshot import Snapshot

NO_PASSIVES = Passives()


def monster_hp(stage: int, b: Balance) -> float:
    return b.monster_hp_base * b.monster_hp_growth**stage


def gold_reward(stage: int, b: Balance) -> float:
    return b.gold_base * b.gold_growth**stage


def boss_gold_reward(stage: int, b: Balance) -> float:
    return gold_reward(stage, b) * b.boss_gold_multiplier


def upgrade_cost(upgrade: str, level: int, b: Balance) -> float:
    return b.upgrade_base_costs[upgrade] * b.upgrade_cost_growth**level


@dataclass(frozen=True)
class Stats:
    attack: float
    attacks_per_second: float
    crit_chance: float
    gold_multiplier: float

    def dps(self, b: Balance) -> float:
        return self.attack * (1 + self.crit_chance * (b.crit_multiplier - 1)) * self.attacks_per_second


def stats_of(s: Snapshot, b: Balance, p: Passives = NO_PASSIVES) -> Stats:
    return Stats(
        attack=(b.attack_base + b.attack_per_level * s.level("attack")) * (1 + p.attack / 100),
        attacks_per_second=(b.attack_speed_base + b.attack_speed_per_level * s.level("attackSpeed")) * (1 + p.attack_speed / 100),
        crit_chance=min(1.0, b.crit_base + b.crit_per_level * s.level("critChance") + p.crit / 100),
        gold_multiplier=(1.0 + b.gold_multiplier_per_level * s.level("goldGain")) * (1 + p.gold / 100),
    )


def capture_rate_of(s: Snapshot, b: Balance, p: Passives = NO_PASSIVES) -> float:
    """기본 포획률(0~1). 실제 판정은 codex가 몬스터 희귀도·보스 배율을 곱해 굴린다."""
    return (b.base_capture_rate + b.capture_rate_per_level * s.level("captureRate")) * (1 + p.capture / 100)
