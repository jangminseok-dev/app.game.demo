"""도감 패시브 합산 — GAME_DESIGN 6장·7장. Flutter `codex.dart`와 같은 규칙이다.

- 몬스터마다 `perStar × 성급`을 종류별로 **더한다**(합연산).
- 지역의 몬스터를 전부(★1 이상) 등록하면 지역 완성 보너스를 더한다.
"""

from __future__ import annotations

from hub.app.dtos.codex_dto import Passives
from hub.app.dtos.monster_dto import MonsterCatalog

_FIELD = {"attack": "attack", "gold": "gold", "attackSpeed": "attack_speed", "crit": "crit", "capture": "capture"}


def compute_passives(stars_by_monster: dict[int, int], catalog: MonsterCatalog) -> Passives:
    totals = {"attack": 0.0, "gold": 0.0, "attack_speed": 0.0, "crit": 0.0, "capture": 0.0}
    for monster in catalog.monsters:
        stars = stars_by_monster.get(monster.id, 0)
        if stars > 0:
            totals[_FIELD[monster.passive_kind]] += monster.passive_per_star * stars
    for region in catalog.regions:
        pool = catalog.monsters_in(region.id)
        if pool and all(stars_by_monster.get(m.id, 0) > 0 for m in pool):
            totals[_FIELD[region.completion_kind]] += region.completion_value
    return Passives(**totals)


def region_completion(stars_by_monster: dict[int, int], catalog: MonsterCatalog) -> dict[str, tuple[int, int]]:
    """지역 id → (등록 수, 전체 수)."""
    return {
        r.id: (sum(1 for m in catalog.monsters_in(r.id) if stars_by_monster.get(m.id, 0) > 0), len(catalog.monsters_in(r.id)))
        for r in catalog.regions
    }
