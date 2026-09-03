from __future__ import annotations

from hub.app.ports.output.balance_port import BalancePort
from save.app.dtos.sync_dto import SyncCommand, SyncResponse
from save.app.ports.input.sync_use_case import SyncUseCase
from save.app.ports.output.save_repository import SaveRepository
from save.app.ports.output.sync_rejection_port import SyncRejectionPort
from save.domain.snapshot import parse_snapshot
from save.domain.validation import delta_rules


class NoSaveToSync(LookupError):
    """먼저 GET /save(load)로 세이브를 만들어야 한다."""


class SyncInteractor(SyncUseCase):
    def __init__(
        self, saves: SaveRepository, balance: BalancePort, rejections: SyncRejectionPort
    ) -> None:
        self._saves = saves
        self._balance = balance
        self._rejections = rejections

    async def sync(self, command: SyncCommand) -> SyncResponse:
        prev = await self._saves.find(command.player_id)
        if prev is None:
            raise NoSaveToSync(f"player={command.player_id}")

        new_snapshot = parse_snapshot(command.state)  # InvalidSnapshot → 라우터가 400
        elapsed = (command.now - prev.synced_at).total_seconds()
        violation = delta_rules.validate(
            parse_snapshot(prev.state), new_snapshot, elapsed, await self._balance.get_balance()
        )
        if violation is not None:
            await self._rejections.record(command.player_id, violation.rule, violation.detail)
            return SyncResponse(
                accepted=False, state=prev.state, synced_at=prev.synced_at, rejected_rule=violation.rule
            )

        saved = await self._saves.upsert(command.player_id, command.state, command.now)
        return SyncResponse(accepted=True, state=saved.state, synced_at=saved.synced_at, rejected_rule=None)
