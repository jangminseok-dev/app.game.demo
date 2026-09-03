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
    bossCaptureMultiplier: float
    maxStars: int
    baseCaptureRate: float
    captureRatePerLevel: float
    capturePityKills: int = Field(description="희귀도 1.0 기준 확정 포획 처치 수. 실제 천장 = 이 값 / 희귀도")
    attackBase: float
    attackPerLevel: float
    attackSpeedBase: float
    attackSpeedPerLevel: float
    critBase: float
    critPerLevel: float
    goldMultiplierPerLevel: float
    upgradeBaseCosts: dict[str, float] = Field(description="업그레이드 종류별 레벨 0 비용")
