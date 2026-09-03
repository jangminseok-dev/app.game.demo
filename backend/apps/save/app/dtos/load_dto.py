from dataclasses import dataclass
from datetime import datetime
from typing import Any

from hub.app.dtos.codex_dto import CodexEntry


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
    codex: tuple[CodexEntry, ...]  # 도감은 세이브 밖(영구 축)이라 함께 실어 보낸다
