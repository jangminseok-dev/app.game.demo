"""포획 판정 — GAME_DESIGN 6장. 서버만 굴린다.

처치 1회마다 `기본 포획률 × 몬스터 희귀도 (× 보스 배율)` 확률로 성공, 성공마다 성급 +1(상한 5).
**천장(pity)**: 마지막 포획 이후 처치가 `pity_kills / 희귀도`에 닿으면 확정 포획. 불운의 상한이다.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from hub.app.dtos.codex_dto import CaptureEvent, KillReport
from hub.app.dtos.monster_dto import MonsterCatalog

# 한 번의 보고에서 굴릴 수 있는 최대 처치 수. 델타 검증이 먼저 막지만 방어선을 하나 더 둔다.
MAX_ROLLS_PER_REPORT = 10_000


class Rng(Protocol):
    def random(self) -> float: ...


@dataclass(frozen=True)
class CodexRow:
    stars: int
    pity_kills: int


def pity_threshold(pity_kills: int, rarity: float) -> int:
    """희귀도 1.0 기준 천장을 희귀도로 나눈다 — 기대값(1/p)의 배수를 일정하게 유지."""
    return max(1, round(pity_kills / rarity))


def roll_captures(
    report: KillReport,
    current: dict[int, CodexRow],
    capture_rate: float,
    catalog: MonsterCatalog,
    boss_multiplier: float,
    max_stars: int,
    pity_kills: int,
    rng: Rng,
) -> tuple[dict[int, CodexRow], tuple[CaptureEvent, ...]]:
    """돌려주는 것: (바뀐 몬스터의 최종 행, 포획 이벤트 목록). 바뀌지 않은 몬스터는 없다."""
    rows = dict(current)
    events: list[CaptureEvent] = []
    rolls = 0

    def _roll(monster_id: int, kills: int, multiplier: float) -> None:
        nonlocal rolls
        monster = catalog.by_id(monster_id)
        if monster is None or kills <= 0:
            return
        p = min(1.0, capture_rate * monster.rarity * multiplier)
        threshold = pity_threshold(pity_kills, monster.rarity)
        row = rows.get(monster_id, CodexRow(0, 0))
        for _ in range(kills):
            if rolls >= MAX_ROLLS_PER_REPORT or row.stars >= max_stars:
                break
            rolls += 1
            pity = row.pity_kills + 1
            by_pity = pity >= threshold
            if by_pity or rng.random() < p:
                row = CodexRow(stars=row.stars + 1, pity_kills=0)
                events.append(CaptureEvent(monster_id=monster_id, stars=row.stars, first=row.stars == 1, by_pity=by_pity))
            else:
                row = CodexRow(stars=row.stars, pity_kills=pity)
        rows[monster_id] = row

    for monster_id, kills in report.normal.items():
        _roll(monster_id, kills, 1.0)
    for monster_id, kills in report.boss.items():
        _roll(monster_id, kills, boss_multiplier)

    changed = {mid: r for mid, r in rows.items() if r != current.get(mid, CodexRow(0, 0))}
    return changed, tuple(events)
