from fastapi import APIRouter, Depends

from save.adapter.inbound.api.schemas.vault_schema import VaultResponseSchema
from save.app.dtos.vault_dto import VaultQuery
from save.app.ports.input.vault_use_case import VaultUseCase
from save.dependencies.vault_provider import get_vault_use_case

vault_router = APIRouter(prefix="/save", tags=["save"])


@vault_router.get("/myself", response_model=VaultResponseSchema)
async def introduce_myself(vault: VaultUseCase = Depends(get_vault_use_case)) -> VaultResponseSchema:
    r = await vault.introduce_myself(VaultQuery(id=2, name="세이브 (save)"))
    return VaultResponseSchema(
        id=r.id,
        name=r.name,
        introduction=r.introduction,
        offlineCapSeconds=r.offline_cap_seconds,
        offlineEfficiency=r.offline_efficiency,
    )
