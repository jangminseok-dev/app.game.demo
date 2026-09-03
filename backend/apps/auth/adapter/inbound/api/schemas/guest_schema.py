from pydantic import BaseModel, Field


class GuestRequestSchema(BaseModel):
    deviceId: str = Field(min_length=1, max_length=128, description="앱이 만든 기기 고유 식별자")


class GuestResponseSchema(BaseModel):
    playerId: int
    accessToken: str
    created: bool = Field(description="이번 요청으로 새 계정이 만들어졌는지")
