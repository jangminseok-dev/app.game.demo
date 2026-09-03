from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class OfflineRewardSchema(BaseModel):
    elapsedSeconds: float
    gold: float


class CodexEntrySchema(BaseModel):
    monsterId: int
    stars: int
    pityKills: int = Field(description="마지막 포획 이후 처치 수 — 천장 진행")


class LoadResponseSchema(BaseModel):
    state: dict[str, Any] = Field(description="클라이언트 세이브 형식 그대로")
    syncedAt: datetime
    created: bool
    offlineReward: OfflineRewardSchema | None = Field(description="보상이 없으면 null")
    codex: list[CodexEntrySchema] = Field(description="도감 등록 목록 — 서버 정본")
