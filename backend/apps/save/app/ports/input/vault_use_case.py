from __future__ import annotations

from abc import ABC, abstractmethod

from save.app.dtos.vault_dto import VaultQuery, VaultResponse


class VaultUseCase(ABC):
    """세이브 (save) 자기소개 — 저장·검증·보상 규칙을 밝힌다."""

    @abstractmethod
    async def introduce_myself(self, query: VaultQuery) -> VaultResponse: ...
