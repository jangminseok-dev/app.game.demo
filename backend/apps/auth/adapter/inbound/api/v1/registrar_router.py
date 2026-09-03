from fastapi import APIRouter, Depends

from auth.adapter.inbound.api.schemas.registrar_schema import RegistrarResponseSchema
from auth.app.dtos.registrar_dto import RegistrarQuery
from auth.app.ports.input.registrar_use_case import RegistrarUseCase
from auth.dependencies.registrar_provider import get_registrar_use_case

registrar_router = APIRouter(prefix="/auth", tags=["auth"])


@registrar_router.get("/myself", response_model=RegistrarResponseSchema)
async def introduce_myself(
    registrar: RegistrarUseCase = Depends(get_registrar_use_case),
) -> RegistrarResponseSchema:
    r = await registrar.introduce_myself(RegistrarQuery(id=1, name="인증 (auth)"))
    return RegistrarResponseSchema(
        id=r.id,
        name=r.name,
        introduction=r.introduction,
        accessTokenTtlSeconds=r.access_token_ttl_seconds,
    )
