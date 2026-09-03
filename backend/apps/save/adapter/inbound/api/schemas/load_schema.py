from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class OfflineRewardSchema(BaseModel):
    elapsedSeconds: float
    gold: float


class LoadResponseSchema(BaseModel):
    state: dict[str, Any] = Field(description="클라이언트 세이브 형식 그대로")
    syncedAt: datetime
    created: bool
    offlineReward: OfflineRewardSchema | None = Field(description="보상이 없으면 null")
