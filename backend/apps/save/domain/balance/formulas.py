"""GAME_DESIGN 4장 공식 + 능력치 환산. Flutter `formulas.dart`·`upgrade.dart`와 1:1이다.

계수는 마스터데이터(허브 `Balance`)에서 오고 공식은 양쪽이 내장한다 — 계수 단일 소유 원칙.
"""

from __future__ import annotations

from dataclasses import dataclass

from hub.app.dtos.balance_dto import Balance
from save.domain.snapshot import Snapshot

# 업그레이드 기본 비용 — Flutter `UpgradeType.baseCost`와 같다.
BASE_COST = {"attack": 10.0, "attackSpeed": 25.0, "critChance": 50.0, "goldGain": 40.0, "captureRate": 100.0}


def monster_hp(stage: int, b: Balance) -> float:
    return b.monster_hp_base * b.monster_hp_growth**stage


def gold_reward(stage: int, b: Balance) -> float:
    return b.gold_base * b.gold_growth**stage


def boss_gold_reward(stage: int, b: Balance) -> float:
    return gold_reward(stage, b) * b.boss_gold_multiplier


def upgrade_cost(upgrade: str, level: int, b: Balance) -> float:
    return BASE_COST[upgrade] * b.upgrade_cost_growth**level


@dataclass(frozen=True)
class Stats:
    attack: float
    attacks_per_second: float
    crit_chance: float
    gold_multiplier: float

    def dps(self, b: Balance) -> float:
        return self.attack * (1 + self.crit_chance * (b.crit_multiplier - 1)) * self.attacks_per_second


def stats_of(s: Snapshot) -> Stats:
    return Stats(
        attack=10 + 5.0 * s.level("attack"),
        attacks_per_second=1.0 + 0.1 * s.level("attackSpeed"),
        crit_chance=min(1.0, 0.05 + 0.01 * s.level("critChance")),
        gold_multiplier=1.0 + 0.05 * s.level("goldGain"),
    )
