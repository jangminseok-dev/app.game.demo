"""클라이언트 세이브 상태의 서버 측 시각 — 검증·보상 계산에 필요한 필드만 읽는다.

원본 JSON은 클라이언트 소유 형식(Flutter `encodeState`)이라 그대로 저장하고,
서버는 여기 정의된 필드만 해석한다. 모르는 필드는 건드리지 않는다.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

UPGRADE_TYPES = ("attack", "attackSpeed", "critChance", "goldGain", "captureRate")


class InvalidSnapshot(ValueError):
    pass


@dataclass(frozen=True)
class Snapshot:
    stage: int
    highest_stage: int
    gold: float
    levels: dict[str, int] = field(default_factory=dict)
    total_kills: int = 0

    def level(self, upgrade: str) -> int:
        return self.levels.get(upgrade, 0)


INITIAL_SNAPSHOT = Snapshot(stage=1, highest_stage=1, gold=0.0, levels={}, total_kills=0)


def initial_state() -> dict[str, Any]:
    """새 계정의 첫 저장 본문 — Flutter `GameState.initial`과 같은 값이다."""
    return {
        "stage": 1,
        "highestStage": 1,
        "gold": 0,
        "levels": {},
        "monsterHp": 11.8,
        "monsterMaxHp": 11.8,
        "isBoss": False,
        "bossTimeLeft": 0,
        "killsOnStage": 0,
        "attackTimer": 0,
        "totalKills": 0,
    }


def parse_snapshot(state: dict[str, Any]) -> Snapshot:
    try:
        stage = int(state["stage"])
        highest = int(state["highestStage"])
        gold = float(state["gold"])
        total_kills = int(state.get("totalKills", 0))
        raw_levels = state.get("levels") or {}
        if not isinstance(raw_levels, dict):
            raise InvalidSnapshot("levels는 객체여야 합니다.")
        levels = {k: int(v) for k, v in raw_levels.items() if k in UPGRADE_TYPES}
    except (KeyError, TypeError, ValueError) as e:
        raise InvalidSnapshot(f"세이브 형식이 올바르지 않습니다: {e}") from e

    if stage < 1 or highest < stage:
        raise InvalidSnapshot("스테이지 값이 올바르지 않습니다.")
    if gold < 0 or total_kills < 0 or any(v < 0 for v in levels.values()):
        raise InvalidSnapshot("음수 값은 허용되지 않습니다.")
    return Snapshot(stage=stage, highest_stage=highest, gold=gold, levels=levels, total_kills=total_kills)
