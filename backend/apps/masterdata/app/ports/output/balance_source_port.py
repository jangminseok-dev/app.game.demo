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
    # 장비 — 드롭 확률·티어 폭·전투력 계수. 4장 "벽" 원칙을 지키도록 계수는 작게 잡는다.
    equip_field_drop_chance: float = 0.08
    equip_boss_drop_chance: float = 1.0
    equip_stages_per_tier: int = 50
    equip_gear_coefficient: float = 0.02
    equip_enhance_per_level: float = 0.03
    # 부화·탐험 — 시간이 재화인 자리.
    expedition_seconds: float = 4 * 3600
    expedition_gold_multiplier: float = 300
    expedition_shards: int = 25
    ad_speed_up_seconds: float = 30 * 60
    # 한 무리에 서는 일반 몬스터 수.
    wave_size_min: int = 3
    wave_size_max: int = 5
    # 한 층에 주어지는 시간과 넘겼을 때 잃는 진행 비율.
    stage_time_limit: float = 120
    stage_fail_kill_penalty: float = 0.5
    # 주인공의 체력·마력·이동과 몬스터의 반격.
    hero_hp_base: float = 200
    hero_hp_per_level: float = 25
    hero_hp_regen_rate: float = 0.03
    hero_revive_seconds: float = 3
    hero_mp_base: float = 100
    hero_mp_per_level: float = 4
    hero_mp_regen_per_second: float = 5
    hero_move_speed: float = 100
    hero_attack_range: float = 34
    monster_move_speed: float = 160
    monster_attack_range: float = 28
    monster_attack_base: float = 2
    monster_attack_growth: float = 1.15
    monster_attacks_per_second: float = 0.6
    boss_attack_multiplier: float = 3.0


class BalanceSourcePort(ABC):
    """밸런스 계수 저장소 포트. 지금은 리포지토리 안 JSON 파일, 운영 중 편집이 필요해지면 DB로."""

    @abstractmethod
    async def load(self) -> BalanceRecord: ...
