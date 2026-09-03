from __future__ import annotations

import logging

from save.app.ports.output.sync_rejection_port import SyncRejectionPort

logger = logging.getLogger(__name__)


class LogSyncRejectionAdapter(SyncRejectionPort):
    """위반을 경고 로그로 남기는 임시 구현. 반복 위반 집계가 필요해지면 PG 어댑터로 교체."""

    async def record(self, player_id: int, rule: str, detail: str) -> None:
        logger.warning("[sync-rejected] player=%s rule=%s %s", player_id, rule, detail)
