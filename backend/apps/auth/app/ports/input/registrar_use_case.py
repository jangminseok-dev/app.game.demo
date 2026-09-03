from __future__ import annotations

from abc import ABC, abstractmethod

from auth.app.dtos.registrar_dto import RegistrarQuery, RegistrarResponse


class RegistrarUseCase(ABC):
    """인증 (auth) 자기소개 — 계정 방식·토큰 수명·제약을 밝힌다."""

    @abstractmethod
    async def introduce_myself(self, query: RegistrarQuery) -> RegistrarResponse: ...
