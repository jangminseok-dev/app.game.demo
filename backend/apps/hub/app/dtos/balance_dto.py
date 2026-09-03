from dataclasses import dataclass


@dataclass(frozen=True)
class Balance:
    """밸런스 계수 — GAME_DESIGN 4장·8장. 클라이언트 `BalanceConfig`와 필드가 1:1이다.

    허브 DTO는 원시 수치만 나른다. 공식(HP = base × growth^stage 등)은 소비자가 갖는다.
    """

    version: int
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
