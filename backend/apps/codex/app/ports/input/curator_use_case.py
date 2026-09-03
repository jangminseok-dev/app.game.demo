from __future__ import annotations

from abc import ABC, abstractmethod

from codex.app.dtos.curator_dto import CuratorQuery, CuratorResponse


class CuratorUseCase(ABC):
    """도감 (codex) 자기소개 — 포획 판정·패시브 규칙을 밝힌다."""

    @abstractmethod
    async def introduce_myself(self, query: CuratorQuery) -> CuratorResponse: ...
