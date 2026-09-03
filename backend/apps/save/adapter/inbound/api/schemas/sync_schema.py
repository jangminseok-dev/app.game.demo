from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class SyncRequestSchema(BaseModel):
    state: dict[str, Any] = Field(description="클라이언트 세이브 형식 그대로 (killLog 포함)")


class CaptureEventSchema(BaseModel):
    monsterId: int
    stars: int = Field(description="포획 후 성급")
    first: bool = Field(description="이번에 처음 등록됐는지")


class SyncResponseSchema(BaseModel):
    accepted: bool
    state: dict[str, Any] = Field(description="서버 정본. 거부됐으면 이 상태로 되돌린다")
    syncedAt: datetime
    rejectedRule: str | None
    captures: list[CaptureEventSchema] = Field(description="이번 보고로 굴린 포획 결과")
