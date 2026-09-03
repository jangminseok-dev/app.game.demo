from dataclasses import dataclass
from datetime import datetime
from typing import Any


@dataclass(frozen=True)
class LoadQuery:
    player_id: int
    now: datetime


@dataclass(frozen=True)
class LoadResponse:
    state: dict[str, Any]
    synced_at: datetime
    created: bool  # 이번 호출로 첫 세이브가 만들어졌는지
    offline_elapsed_seconds: float  # 보상 없으면 0
    offline_gold: float
