from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from auth.adapter.outbound.jwt_token_issuer_adapter import JwtTokenIssuerAdapter
from auth.adapter.outbound.pg.player_pg_repository import PlayerPgRepository
from auth.app.ports.input.guest_use_case import GuestUseCase
from auth.app.use_cases.guest_interactor import GuestInteractor
from core.database import get_db


def get_guest_use_case(db: AsyncSession = Depends(get_db)) -> GuestUseCase:
    return GuestInteractor(players=PlayerPgRepository(session=db), tokens=JwtTokenIssuerAdapter())
