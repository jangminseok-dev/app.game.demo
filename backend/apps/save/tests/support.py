"""save 테스트 공용 스텁·픽스처."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from hub.app.dtos.balance_dto import Balance
from save.app.ports.output.save_repository import SaveRecord

BALANCE = Balance(
    version=1,
    monster_hp_base=10,
    monster_hp_growth=1.18,
    boss_hp_multiplier=10,
    boss_time_limit=30,
    gold_base=5,
    gold_growth=1.15,
    boss_gold_multiplier=10,
    upgrade_cost_growth=1.09,
    kills_per_stage=10,
    crit_multiplier=2.0,
    offline_cap_seconds=8 * 3600,
    offline_efficiency=0.5,
    offline_min_seconds=60,
)

T0 = datetime(2026, 9, 3, 12, 0, tzinfo=UTC)


def state(**overrides: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "stage": 1, "highestStage": 1, "gold": 0, "levels": {}, "monsterHp": 11.8,
        "monsterMaxHp": 11.8, "isBoss": False, "bossTimeLeft": 0, "killsOnStage": 0,
        "attackTimer": 0, "totalKills": 0,
    }
    merged = {**base, **overrides}
    # stage만 올리면 highestStage도 따라 올린다 — 스냅샷 규칙(highest >= stage).
    # 둘 다 준 경우(규칙 위반 케이스 테스트)는 그대로 둔다.
    if "highestStage" not in overrides and isinstance(merged["stage"], int):
        merged["highestStage"] = max(merged["highestStage"], merged["stage"])
    return merged


class StubBalance:
    async def get_balance(self) -> Balance:
        return BALANCE


class StubSaves:
    def __init__(self, record: SaveRecord | None = None):
        self.record = record
        self.upserts = 0

    async def find(self, player_id):
        return self.record if self.record and self.record.player_id == player_id else None

    async def upsert(self, player_id, state, synced_at):
        self.upserts += 1
        self.record = SaveRecord(player_id=player_id, state=state, synced_at=synced_at)
        return self.record


class StubRejections:
    def __init__(self):
        self.records: list[tuple[int, str, str]] = []

    async def record(self, player_id, rule, detail):
        self.records.append((player_id, rule, detail))
