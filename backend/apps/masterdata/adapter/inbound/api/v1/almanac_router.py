from fastapi import APIRouter, Depends

from masterdata.adapter.inbound.api.schemas.almanac_schema import AlmanacResponseSchema
from masterdata.app.dtos.almanac_dto import AlmanacQuery
from masterdata.app.ports.input.almanac_use_case import AlmanacUseCase
from masterdata.dependencies.almanac_provider import get_almanac_use_case

almanac_router = APIRouter(prefix="/masterdata", tags=["masterdata"])


@almanac_router.get("/myself", response_model=AlmanacResponseSchema)
async def introduce_myself(
    almanac: AlmanacUseCase = Depends(get_almanac_use_case),
) -> AlmanacResponseSchema:
    r = await almanac.introduce_myself(AlmanacQuery(id=3, name="마스터데이터 (masterdata)"))
    return AlmanacResponseSchema(
        id=r.id, name=r.name, introduction=r.introduction, balanceVersion=r.balance_version
    )
