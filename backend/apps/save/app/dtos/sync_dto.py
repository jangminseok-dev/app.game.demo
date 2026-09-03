from dataclasses import dataclass
from datetime import datetime
from typing import Any

from hub.app.dtos.codex_dto import CaptureEvent


@dataclass(frozen=True)
class SyncCommand:
    player_id: int
    state: dict[str, Any]
    now: datetime


@dataclass(frozen=True)
class SyncResponse:
    accepted: bool
    state: dict[str, Any]  # 서버가 정본으로 인정한 상태 (거부 시 롤백된 상태). 수락 시 killLog는 비워져 있다
    synced_at: datetime
    rejected_rule: str | None
    captures: tuple[CaptureEvent, ...]  # 이번 보고로 굴린 포획 결과
