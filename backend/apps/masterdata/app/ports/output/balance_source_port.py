from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class BalanceRecord:
    """저장된 밸런스 계수 1벌. 어댑터(파일/DB)가 옮겨 담는다."""

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
    # 능력치 = base + per_level × 레벨 (선형, GAME_DESIGN 4장)
    attack_base: float
    attack_per_level: float
    attack_speed_base: float
    attack_speed_per_level: float
    crit_base: float
    crit_per_level: float
    gold_multiplier_per_level: float
    # 업그레이드 기본 비용(레벨 0). 비용 = base × upgrade_cost_growth^level
    upgrade_base_costs: dict[str, float]


class BalanceSourcePort(ABC):
    """밸런스 계수 저장소 포트. 지금은 리포지토리 안 JSON 파일, 운영 중 편집이 필요해지면 DB로."""

    @abstractmethod
    async def load(self) -> BalanceRecord: ...
