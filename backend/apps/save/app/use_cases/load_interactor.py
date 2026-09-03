from __future__ import annotations

from hub.app.ports.output.balance_port import BalancePort
from hub.app.ports.output.codex_port import CodexPort
from save.app.dtos.load_dto import LoadQuery, LoadResponse
from save.app.ports.input.load_use_case import LoadUseCase
from save.app.ports.output.save_repository import SaveRepository
from save.domain.balance import offline_reward
from save.domain.snapshot import initial_state, parse_snapshot


class LoadInteractor(LoadUseCase):
    """없으면 초기 세이브를 만들고, 있으면 서버 시간 기준 오프라인 보상을 더해 돌려준다.

    보상은 `synced_at`을 지금으로 옮기며 저장하므로 두 번 받을 수 없다.
    도감 패시브는 보상 계산(DPS·골드 배율)에 반영되고, 도감 목록도 함께 실어 보낸다.
    """

    def __init__(self, saves: SaveRepository, balance: BalancePort, codex: CodexPort) -> None:
        self._saves = saves
        self._balance = balance
        self._codex = codex

    async def load(self, query: LoadQuery) -> LoadResponse:
        record = await self._saves.find(query.player_id)
        if record is None:
            created = await self._saves.upsert(query.player_id, initial_state(), query.now)
            return LoadResponse(
                state=created.state, synced_at=created.synced_at, created=True,
                offline_elapsed_seconds=0, offline_gold=0, codex=(),
            )

        entries = await self._codex.get_entries(query.player_id)
        b = await self._balance.get_balance()
        passives = await self._codex.get_passives(query.player_id)
        elapsed = (query.now - record.synced_at).total_seconds()
        reward = offline_reward.calculate(parse_snapshot(record.state), elapsed, b, passives)
        if not reward.paid:
            return LoadResponse(
                state=record.state, synced_at=record.synced_at, created=False,
                offline_elapsed_seconds=0, offline_gold=0, codex=entries,
            )

        state = {**record.state, "gold": float(record.state["gold"]) + reward.gold}
        saved = await self._saves.upsert(query.player_id, state, query.now)
        return LoadResponse(
            state=saved.state, synced_at=saved.synced_at, created=False,
            offline_elapsed_seconds=reward.elapsed_seconds, offline_gold=reward.gold, codex=entries,
        )
