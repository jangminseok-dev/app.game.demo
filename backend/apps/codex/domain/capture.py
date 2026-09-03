"""포획 판정 — GAME_DESIGN 6장. 서버만 굴린다.

처치 1회마다 `기본 포획률 × 몬스터 희귀도 (× 보스 배율)` 확률로 성공, 성공마다 성급 +1(상한 5).
"""

from __future__ import annotations

from typing import Protocol

from hub.app.dtos.codex_dto import CaptureEvent, KillReport
from hub.app.dtos.monster_dto import MonsterCatalog

# 한 번의 보고에서 굴릴 수 있는 최대 처치 수. 델타 검증이 먼저 막지만 방어선을 하나 더 둔다.
MAX_ROLLS_PER_REPORT = 10_000


class Rng(Protocol):
    def random(self) -> float: ...


def roll_captures(
    report: KillReport,
    current_stars: dict[int, int],
    capture_rate: float,
    catalog: MonsterCatalog,
    boss_multiplier: float,
    max_stars: int,
    rng: Rng,
) -> tuple[dict[int, int], tuple[CaptureEvent, ...]]:
    """돌려주는 것: (바뀐 몬스터의 최종 성급, 포획 이벤트 목록). 성급이 안 바뀐 몬스터는 없다."""
    stars = dict(current_stars)
    events: list[CaptureEvent] = []
    rolls = 0

    def _roll(monster_id: int, kills: int, multiplier: float) -> None:
        nonlocal rolls
        monster = catalog.by_id(monster_id)
        if monster is None or kills <= 0:
            return
        p = min(1.0, capture_rate * monster.rarity * multiplier)
        for _ in range(kills):
            if rolls >= MAX_ROLLS_PER_REPORT:
                return
            rolls += 1
            if stars.get(monster_id, 0) >= max_stars:
                return
            if rng.random() < p:
                first = stars.get(monster_id, 0) == 0
                stars[monster_id] = stars.get(monster_id, 0) + 1
                events.append(CaptureEvent(monster_id=monster_id, stars=stars[monster_id], first=first))

    for monster_id, kills in report.normal.items():
        _roll(monster_id, kills, 1.0)
    for monster_id, kills in report.boss.items():
        _roll(monster_id, kills, boss_multiplier)

    changed = {mid: s for mid, s in stars.items() if s != current_stars.get(mid, 0)}
    return changed, tuple(events)
