from __future__ import annotations

from abc import ABC, abstractmethod

from auth.app.dtos.guest_dto import GuestCommand, GuestResponse


class GuestUseCase(ABC):
    """게스트 시작 — 기기 식별자로 계정을 만들거나 찾고 액세스 토큰을 낸다 (GAME_DESIGN 12장)."""

    @abstractmethod
    async def start(self, command: GuestCommand) -> GuestResponse: ...
