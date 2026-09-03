from __future__ import annotations

from hub.app.ports.output.codex_port import CodexPort


def get_codex_port() -> CodexPort:
    raise NotImplementedError("CodexPort는 main.py에서 codex 게이트웨이로 주입된다")
