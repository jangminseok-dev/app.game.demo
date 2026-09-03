from datetime import UTC, datetime

from fastapi import APIRouter, Depends

from core.security import get_current_player_id
from save.adapter.inbound.api.schemas.load_schema import (
    CodexEntrySchema,
    LoadResponseSchema,
    OfflineRewardSchema,
)
from save.app.dtos.load_dto import LoadQuery
from save.app.ports.input.load_use_case import LoadUseCase
from save.dependencies.load_provider import get_load_use_case

load_router = APIRouter(prefix="/save", tags=["save"])


@load_router.get("", response_model=LoadResponseSchema)
async def load_save(
    player_id: int = Depends(get_current_player_id),
    load: LoadUseCase = Depends(get_load_use_case),
) -> LoadResponseSchema:
    r = await load.load(LoadQuery(player_id=player_id, now=datetime.now(UTC)))
    return LoadResponseSchema(
        state=r.state,
        syncedAt=r.synced_at,
        created=r.created,
        offlineReward=(
            OfflineRewardSchema(elapsedSeconds=r.offline_elapsed_seconds, gold=r.offline_gold)
            if r.offline_gold > 0
            else None
        ),
        codex=[CodexEntrySchema(monsterId=e.monster_id, stars=e.stars, pityKills=e.pity_kills) for e in r.codex],
    )
