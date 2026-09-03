from fastapi import APIRouter, Depends, Query

from masterdata.adapter.inbound.api.schemas.bestiary_schema import (
    BestiaryResponseSchema,
    CompletionBonusSchema,
    MonsterSchema,
    PassiveSchema,
    RegionSchema,
)
from masterdata.app.dtos.bestiary_dto import BestiaryQuery
from masterdata.app.ports.input.bestiary_use_case import BestiaryUseCase
from masterdata.dependencies.bestiary_provider import get_bestiary_use_case

bestiary_router = APIRouter(prefix="/masterdata", tags=["masterdata"])


@bestiary_router.get("/monsters", response_model=BestiaryResponseSchema)
async def fetch_monsters(
    version: int | None = Query(None, description="클라이언트가 캐시한 버전"),
    bestiary: BestiaryUseCase = Depends(get_bestiary_use_case),
) -> BestiaryResponseSchema:
    r = await bestiary.fetch(BestiaryQuery(client_version=version))
    c = r.catalog
    return BestiaryResponseSchema(
        version=c.version,
        unchanged=r.unchanged,
        regions=[
            RegionSchema(
                id=x.id, name=x.name, stageFrom=x.stage_from, stageTo=x.stage_to,
                completionBonus=CompletionBonusSchema(kind=x.completion_kind, value=x.completion_value),
            )
            for x in c.regions
        ],
        monsters=[
            MonsterSchema(
                id=m.id, name=m.name, region=m.region, element=m.element, rarity=m.rarity,
                passive=PassiveSchema(kind=m.passive_kind, perStar=m.passive_per_star),
            )
            for m in c.monsters
        ],
    )
