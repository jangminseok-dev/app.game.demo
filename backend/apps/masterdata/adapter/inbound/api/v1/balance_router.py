from fastapi import APIRouter, Depends, Query

from masterdata.adapter.inbound.api.schemas.balance_schema import BalanceResponseSchema
from masterdata.app.dtos.balance_dto import BalanceQuery
from masterdata.app.ports.input.balance_use_case import BalanceUseCase
from masterdata.dependencies.balance_provider import get_balance_use_case

balance_router = APIRouter(prefix="/masterdata", tags=["masterdata"])


@balance_router.get("/balance", response_model=BalanceResponseSchema)
async def fetch_balance(
    version: int | None = Query(None, description="클라이언트가 캐시한 버전"),
    balance: BalanceUseCase = Depends(get_balance_use_case),
) -> BalanceResponseSchema:
    r = await balance.fetch(BalanceQuery(client_version=version))
    return BalanceResponseSchema(
        version=r.version,
        unchanged=r.unchanged,
        monsterHpBase=r.monster_hp_base,
        monsterHpGrowth=r.monster_hp_growth,
        bossHpMultiplier=r.boss_hp_multiplier,
        bossTimeLimit=r.boss_time_limit,
        goldBase=r.gold_base,
        goldGrowth=r.gold_growth,
        bossGoldMultiplier=r.boss_gold_multiplier,
        upgradeCostGrowth=r.upgrade_cost_growth,
        killsPerStage=r.kills_per_stage,
        critMultiplier=r.crit_multiplier,
        offlineCapSeconds=r.offline_cap_seconds,
        offlineEfficiency=r.offline_efficiency,
        offlineMinSeconds=r.offline_min_seconds,
    )
