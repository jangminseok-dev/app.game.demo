from __future__ import annotations

import random

from codex.app.ports.output.codex_repository import CodexRepository
from codex.domain.capture import CodexRow, Rng, roll_captures
from codex.domain.passives import compute_passives
from hub.app.dtos.codex_dto import CaptureEvent, CodexEntry, KillReport, Passives
from hub.app.ports.output.balance_port import BalancePort
from hub.app.ports.output.codex_port import CodexPort
from hub.app.ports.output.monster_catalog_port import MonsterCatalogPort


def _entries(rows: dict[int, CodexRow]) -> tuple[CodexEntry, ...]:
    return tuple(
        CodexEntry(monster_id=m, stars=r.stars, pity_kills=r.pity_kills) for m, r in sorted(rows.items())
    )


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
        return _entries(await self._entries.rows_by_monster(player_id))

    async def get_passives(self, player_id: int) -> Passives:
        rows = await self._entries.rows_by_monster(player_id)
        stars = {m: r.stars for m, r in rows.items() if r.stars > 0}
        if not stars:
            return Passives()
        return compute_passives(stars, await self._catalog.get_catalog())

    async def register_kills(
        self, player_id: int, report: KillReport, capture_rate: float
    ) -> tuple[tuple[CaptureEvent, ...], tuple[CodexEntry, ...]]:
        current = await self._entries.rows_by_monster(player_id)
        if report.total <= 0:
            return (), _entries(current)
        b = await self._balance.get_balance()
        changed, events = roll_captures(
            report,
            current,
            capture_rate,
            await self._catalog.get_catalog(),
            b.boss_capture_multiplier,
            b.max_stars,
            b.capture_pity_kills,
            self._rng,
        )
        await self._entries.save_rows(player_id, changed)
        return events, _entries({**current, **changed})
