from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status

from core.security import get_current_player_id
from save.adapter.inbound.api.schemas.sync_schema import SyncRequestSchema, SyncResponseSchema
from save.app.dtos.sync_dto import SyncCommand
from save.app.ports.input.sync_use_case import SyncUseCase
from save.app.use_cases.sync_interactor import NoSaveToSync
from save.dependencies.sync_provider import get_sync_use_case
from save.domain.snapshot import InvalidSnapshot

sync_router = APIRouter(prefix="/save", tags=["save"])


@sync_router.put("", response_model=SyncResponseSchema)
async def sync_save(
    body: SyncRequestSchema,
    player_id: int = Depends(get_current_player_id),
    sync: SyncUseCase = Depends(get_sync_use_case),
) -> SyncResponseSchema:
    try:
        r = await sync.sync(SyncCommand(player_id=player_id, state=body.state, now=datetime.now(UTC)))
    except InvalidSnapshot as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except NoSaveToSync:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="세이브가 없습니다. 먼저 GET /save를 부르세요."
        )
    return SyncResponseSchema(
        accepted=r.accepted, state=r.state, syncedAt=r.synced_at, rejectedRule=r.rejected_rule
    )
