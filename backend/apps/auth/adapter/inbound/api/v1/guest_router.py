from fastapi import APIRouter, Depends, HTTPException, status

from auth.adapter.inbound.api.schemas.guest_schema import GuestRequestSchema, GuestResponseSchema
from auth.app.dtos.guest_dto import GuestCommand
from auth.app.ports.input.guest_use_case import GuestUseCase
from auth.dependencies.guest_provider import get_guest_use_case
from auth.domain.device import InvalidDeviceId

guest_router = APIRouter(prefix="/auth", tags=["auth"])


@guest_router.post("/guest", response_model=GuestResponseSchema)
async def start_guest(
    body: GuestRequestSchema,
    guest: GuestUseCase = Depends(get_guest_use_case),
) -> GuestResponseSchema:
    try:
        r = await guest.start(GuestCommand(device_id=body.deviceId))
    except InvalidDeviceId as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    return GuestResponseSchema(playerId=r.player_id, accessToken=r.access_token, created=r.created)
