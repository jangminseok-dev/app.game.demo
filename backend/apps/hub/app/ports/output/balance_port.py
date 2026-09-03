from __future__ import annotations

from abc import ABC, abstractmethod

from hub.app.dtos.balance_dto import Balance


class BalancePort(ABC):
    """밸런스 계수 조회 협력 — masterdata(구현)와 save(소비)를 잇는다.

    save는 오프라인 보상·델타 검증에 같은 계수를 써야 하고, 계수의 소유자는 masterdata다.
    """

    @abstractmethod
    async def get_balance(self) -> Balance: ...
