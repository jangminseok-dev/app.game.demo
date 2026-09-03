from __future__ import annotations

from auth.app.dtos.guest_dto import GuestCommand, GuestResponse
from auth.app.ports.input.guest_use_case import GuestUseCase
from auth.app.ports.output.player_repository import PlayerRepository
from auth.app.ports.output.token_issuer_port import TokenIssuerPort
from auth.domain.device import normalize_device_id


class GuestInteractor(GuestUseCase):
    def __init__(self, players: PlayerRepository, tokens: TokenIssuerPort) -> None:
        self._players = players
        self._tokens = tokens

    async def start(self, command: GuestCommand) -> GuestResponse:
        device_id = normalize_device_id(command.device_id)  # 위반 시 InvalidDeviceId → 라우터가 400
        player = await self._players.find_by_device_id(device_id)
        created = player is None
        if player is None:
            player = await self._players.create(device_id)
        return GuestResponse(
            player_id=player.id,
            access_token=self._tokens.issue(player.id),
            created=created,
        )
