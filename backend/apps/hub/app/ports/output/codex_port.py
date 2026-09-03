from __future__ import annotations

from abc import ABC, abstractmethod

from hub.app.dtos.codex_dto import CaptureEvent, CodexEntry, KillReport, Passives


class CodexPort(ABC):
    """도감 협력 — codex(구현)와 save(소비)를 잇는다.

    save는 동기화 때 처치 보고를 넘기고(포획 판정은 codex가 한다), 검증·오프라인 보상에 쓸
    패시브 합계를 받아 간다.
    """

    @abstractmethod
    async def get_entries(self, player_id: int) -> tuple[CodexEntry, ...]:
        """미등록(stars 0)이라도 천장 카운트가 있는 행은 포함한다."""
        ...

    @abstractmethod
    async def get_passives(self, player_id: int) -> Passives: ...

    @abstractmethod
    async def register_kills(
        self, player_id: int, report: KillReport, capture_rate: float
    ) -> tuple[tuple[CaptureEvent, ...], tuple[CodexEntry, ...]]:
        """처치 보고를 받아 포획을 굴리고 도감을 갱신한다.

        `capture_rate`는 플레이어의 기본 포획률(0~1). 돌려주는 것: (포획 이벤트, 갱신 후 도감 전체).
        """
        ...
