from __future__ import annotations

import random

from codex.app.ports.output.codex_repository import CodexRepository
from codex.domain.capture import Rng, roll_captures
from codex.domain.passives import compute_passives
from hub.app.dtos.codex_dto import CaptureEvent, CodexEntry, KillReport, Passives
from hub.app.ports.output.balance_port import BalancePort
from hub.app.ports.output.codex_port import CodexPort
from hub.app.ports.output.monster_catalog_port import MonsterCatalogPort


class CodexGateway(CodexPort):
    """허브 `CodexPort` 구현 — save가 처치를 보고하고 패시브를 받아 가는 창구."""

    def __init__(
        self,
        entries: CodexRepository,
        catalog: MonsterCatalogPort,
        balance: BalancePort,
        rng: Rng | None = None,
    ) -> None:
        self._entries = entries
        self._catalog = catalog
        self._balance = balance
        self._rng: Rng = rng or random.SystemRandom()

    async def get_entries(self, player_id: int) -> tuple[CodexEntry, ...]:
        stars = await self._entries.stars_by_monster(player_id)
        return tuple(CodexEntry(monster_id=m, stars=s) for m, s in sorted(stars.items()))

    async def get_passives(self, player_id: int) -> Passives:
        stars = await self._entries.stars_by_monster(player_id)
        if not stars:
            return Passives()
        return compute_passives(stars, await self._catalog.get_catalog())

    async def register_kills(
        self, player_id: int, report: KillReport, capture_rate: float
    ) -> tuple[CaptureEvent, ...]:
        if report.total <= 0:
            return ()
        b = await self._balance.get_balance()
        changed, events = roll_captures(
            report,
            await self._entries.stars_by_monster(player_id),
            capture_rate,
            await self._catalog.get_catalog(),
            b.boss_capture_multiplier,
            b.max_stars,
            self._rng,
        )
        await self._entries.set_stars(player_id, changed)
        return events
