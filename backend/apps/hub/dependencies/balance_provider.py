from __future__ import annotations

from hub.app.ports.output.balance_port import BalancePort


def get_balance_port() -> BalancePort:
    """main.py가 `dependency_overrides`로 masterdata의 게이트웨이를 주입한다(허브 격리)."""
    raise NotImplementedError("BalancePort는 main.py에서 masterdata 게이트웨이로 주입된다")
