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
    equipFieldDropChance: float
    equipBossDropChance: float
    equipStagesPerTier: int = Field(description="이 층수마다 장비 티어가 한 단계 오른다")
    equipGearCoefficient: float
    equipEnhancePerLevel: float
    expeditionSeconds: float
    expeditionGoldMultiplier: float
    expeditionShards: int
    adSpeedUpSeconds: float
    waveSizeMin: int
    waveSizeMax: int
    stageTimeLimit: float
    stageFailKillPenalty: float
    craftCostBase: float
    craftCostPerLevel: float
    craftBiasPerLevel: float
    heroHpBase: float
    heroHpPerLevel: float
    heroHpStageGrowth: float
    heroHpRegenRate: float
    heroReviveSeconds: float
    heroMpBase: float
    heroMpPerLevel: float
    heroMpRegenPerSecond: float
    heroMoveSpeed: float
    heroAttackRange: float
    monsterMoveSpeed: float
    monsterAttackRange: float
    monsterAttackBase: float
    monsterAttackGrowth: float
    monsterAttacksPerSecond: float
    bossAttackMultiplier: float
