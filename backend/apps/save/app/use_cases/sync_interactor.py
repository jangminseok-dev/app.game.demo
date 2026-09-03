from __future__ import annotations

from hub.app.ports.output.balance_port import BalancePort
from hub.app.ports.output.codex_port import CodexPort
from save.app.dtos.sync_dto import SyncCommand, SyncResponse
from save.app.ports.input.sync_use_case import SyncUseCase
from save.app.ports.output.save_repository import SaveRepository
from save.app.ports.output.sync_rejection_port import SyncRejectionPort
from save.domain.balance.formulas import capture_rate_of
from save.domain.snapshot import parse_snapshot, with_kill_log_cleared
from save.domain.validation import delta_rules


class NoSaveToSync(LookupError):
    """먼저 GET /save(load)로 세이브를 만들어야 한다."""


class SyncInteractor(SyncUseCase):
    """델타 검증 → 통과하면 처치 보고를 도감에 넘겨 포획을 굴리고, 보고를 비운 상태를 저장한다."""

    def __init__(
        self, saves: SaveRepository, balance: BalancePort, rejections: SyncRejectionPort, codex: CodexPort
    ) -> None:
        self._saves = saves
        self._balance = balance
        self._rejections = rejections
        self._codex = codex

    async def sync(self, command: SyncCommand) -> SyncResponse:
        prev = await self._saves.find(command.player_id)
        if prev is None:
            raise NoSaveToSync(f"player={command.player_id}")

        new_snapshot = parse_snapshot(command.state)  # InvalidSnapshot → 라우터가 400
        passives = await self._codex.get_passives(command.player_id)
        balance = await self._balance.get_balance()
        elapsed = (command.now - prev.synced_at).total_seconds()
        violation = delta_rules.validate(parse_snapshot(prev.state), new_snapshot, elapsed, balance, passives)
        if violation is not None:
            await self._rejections.record(command.player_id, violation.rule, violation.detail)
            return SyncResponse(
                accepted=False, state=prev.state, synced_at=prev.synced_at,
                rejected_rule=violation.rule, captures=(), codex=(),
            )

        captures, codex = await self._codex.register_kills(
            command.player_id, new_snapshot.kill_report, capture_rate_of(new_snapshot, balance, passives)
        )
        saved = await self._saves.upsert(command.player_id, with_kill_log_cleared(command.state), command.now)
        return SyncResponse(
            accepted=True, state=saved.state, synced_at=saved.synced_at, rejected_rule=None,
            captures=captures, codex=codex,
        )
