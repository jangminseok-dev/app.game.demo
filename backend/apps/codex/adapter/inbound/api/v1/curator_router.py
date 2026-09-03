from fastapi import APIRouter, Depends

from codex.adapter.inbound.api.schemas.curator_schema import CuratorResponseSchema
from codex.app.dtos.curator_dto import CuratorQuery
from codex.app.ports.input.curator_use_case import CuratorUseCase
from codex.dependencies.curator_provider import get_curator_use_case

curator_router = APIRouter(prefix="/codex", tags=["codex"])


@curator_router.get("/myself", response_model=CuratorResponseSchema)
async def introduce_myself(curator: CuratorUseCase = Depends(get_curator_use_case)) -> CuratorResponseSchema:
    r = await curator.introduce_myself(CuratorQuery(id=4, name="도감 (codex)"))
    return CuratorResponseSchema(
        id=r.id, name=r.name, introduction=r.introduction, monsterCount=r.monster_count, maxStars=r.max_stars
    )
