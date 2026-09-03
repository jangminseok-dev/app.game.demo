from __future__ import annotations

import json
from pathlib import Path

from masterdata.app.ports.output.balance_source_port import BalanceRecord, BalanceSourcePort

_DEFAULT_PATH = Path(__file__).resolve().parents[3] / "resources" / "balance.json"


class FileBalanceSourceAdapter(BalanceSourcePort):
    """`resources/balance.json`을 읽는다. 매 호출 읽기 — 파일을 고치면 재기동 없이 반영."""

    def __init__(self, path: Path | None = None) -> None:
        self._path = path or _DEFAULT_PATH

    async def load(self) -> BalanceRecord:
        raw = json.loads(self._path.read_text(encoding="utf-8"))
        return BalanceRecord(**raw)
