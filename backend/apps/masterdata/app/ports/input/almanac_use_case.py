from __future__ import annotations

from abc import ABC, abstractmethod

from masterdata.app.dtos.almanac_dto import AlmanacQuery, AlmanacResponse


class AlmanacUseCase(ABC):
    """마스터데이터 (masterdata) 자기소개 — 제공 데이터·제약을 밝힌다."""

    @abstractmethod
    async def introduce_myself(self, query: AlmanacQuery) -> AlmanacResponse: ...
