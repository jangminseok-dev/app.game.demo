from dataclasses import dataclass
from datetime import datetime
from typing import Any


@dataclass(frozen=True)
class SyncCommand:
    player_id: int
    state: dict[str, Any]
    now: datetime


@dataclass(frozen=True)
class SyncResponse:
    accepted: bool
    state: dict[str, Any]  # 서버가 정본으로 인정한 상태 (거부 시 롤백된 상태)
    synced_at: datetime
    rejected_rule: str | None
