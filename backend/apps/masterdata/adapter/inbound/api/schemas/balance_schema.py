from pydantic import BaseModel, Field


class BalanceResponseSchema(BaseModel):
    version: int
    unchanged: bool = Field(description="클라이언트 버전과 같으면 true — 캐시를 그대로 쓴다")
    monsterHpBase: float
    monsterHpGrowth: float
    bossHpMultiplier: float
    bossTimeLimit: float
    goldBase: float
    goldGrowth: float
    bossGoldMultiplier: float
    upgradeCostGrowth: float
    killsPerStage: int
    critMultiplier: float
    offlineCapSeconds: float
    offlineEfficiency: float
    offlineMinSeconds: float
