"""오프라인 보상 — GAME_DESIGN 8장. Flutter `offline_reward.dart`와 같은 식, 시간만 서버 것이다."""

from __future__ import annotations

from dataclasses import dataclass

from hub.app.dtos.balance_dto import Balance
from hub.app.dtos.codex_dto import Passives
from save.domain.balance.formulas import NO_PASSIVES, gold_reward, monster_hp, stats_of
from save.domain.snapshot import Snapshot


@dataclass(frozen=True)
class OfflineReward:
    elapsed_seconds: float  # 상한 적용 후
    gold: float

    @property
    def paid(self) -> bool:
        return self.gold > 0


NONE = OfflineReward(elapsed_seconds=0.0, gold=0.0)


def calculate(s: Snapshot, raw_elapsed_seconds: float, b: Balance, p: Passives = NO_PASSIVES) -> OfflineReward:
    if raw_elapsed_seconds < b.offline_min_seconds:
        return NONE
    seconds = min(raw_elapsed_seconds, b.offline_cap_seconds)
    stats = stats_of(s, p)
    kills = stats.dps(b) * seconds / monster_hp(s.stage, b)
    gold = kills * gold_reward(s.stage, b) * stats.gold_multiplier * b.offline_efficiency
    return OfflineReward(elapsed_seconds=seconds, gold=gold)
