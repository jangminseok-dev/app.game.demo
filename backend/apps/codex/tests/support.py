"""codex 테스트 공용 — 작은 카탈로그(지역 2 × 몬스터 2)와 스텁."""

from __future__ import annotations

from hub.app.dtos.balance_dto import Balance
from hub.app.dtos.monster_dto import Monster, MonsterCatalog, Region

CATALOG = MonsterCatalog(
    version=1,
    regions=(
        Region("forest", "숲", 1, 10, "attack", 20),
        Region("cave", "동굴", 11, None, "gold", 20),
    ),
    monsters=(
        Monster(1, "슬라임", "forest", "neutral", 1.0, "gold", 0.5),
        Monster(2, "늑대", "forest", "wind", 0.5, "attackSpeed", 0.3),
        Monster(3, "박쥐", "cave", "wind", 1.0, "crit", 0.2),
        Monster(4, "골렘", "cave", "earth", 0.3, "attack", 0.6),
    ),
)

BALANCE = Balance(
    version=1, monster_hp_base=10, monster_hp_growth=1.18, boss_hp_multiplier=10, boss_time_limit=30,
    gold_base=5, gold_growth=1.15, boss_gold_multiplier=10, upgrade_cost_growth=1.09, kills_per_stage=10,
    crit_multiplier=2.0, offline_cap_seconds=28800, offline_efficiency=0.5, offline_min_seconds=60,
    boss_capture_multiplier=4.0, max_stars=5,
)


class StubCatalog:
    async def get_catalog(self):
        return CATALOG


class StubBalance:
    async def get_balance(self):
        return BALANCE


class StubEntries:
    def __init__(self, stars: dict[int, int] | None = None):
        self.stars = dict(stars or {})
        self.writes: list[dict[int, int]] = []

    async def stars_by_monster(self, player_id):
        return dict(self.stars)

    async def set_stars(self, player_id, stars_by_monster):
        self.writes.append(dict(stars_by_monster))
        self.stars.update(stars_by_monster)


class SeqRng:
    """미리 정한 값을 순서대로 돌려주는 난수. 다 쓰면 1.0(실패)."""

    def __init__(self, values):
        self._values = list(values)

    def random(self):
        return self._values.pop(0) if self._values else 1.0
