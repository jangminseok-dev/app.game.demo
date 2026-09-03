from pydantic import BaseModel, Field


class CompletionBonusSchema(BaseModel):
    kind: str
    value: float


class RegionSchema(BaseModel):
    id: str
    name: str
    stageFrom: int
    stageTo: int | None = Field(description="null이면 마지막 지역(무한)")
    completionBonus: CompletionBonusSchema


class PassiveSchema(BaseModel):
    kind: str
    perStar: float


class MonsterSchema(BaseModel):
    id: int
    name: str
    region: str
    element: str
    rarity: float
    passive: PassiveSchema


class BestiaryResponseSchema(BaseModel):
    version: int
    unchanged: bool
    regions: list[RegionSchema]
    monsters: list[MonsterSchema]
