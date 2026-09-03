from dataclasses import dataclass


@dataclass(frozen=True)
class BalanceQuery:
    """클라이언트가 가진 버전. 같으면 본문 없이 `unchanged`로 답한다."""

    client_version: int | None


@dataclass(frozen=True)
class BalanceResponse:
    version: int
    unchanged: bool
    monster_hp_base: float
    monster_hp_growth: float
    boss_hp_multiplier: float
    boss_time_limit: float
    gold_base: float
    gold_growth: float
    boss_gold_multiplier: float
    upgrade_cost_growth: float
    kills_per_stage: int
    crit_multiplier: float
    offline_cap_seconds: float
    offline_efficiency: float
    offline_min_seconds: float
    boss_capture_multiplier: float
    max_stars: int
    base_capture_rate: float
    capture_rate_per_level: float
    capture_pity_kills: int  # 희귀도 1.0 기준. 실제 천장 = pity / rarity
