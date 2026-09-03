from __future__ import annotations

from abc import ABC, abstractmethod


class TokenIssuerPort(ABC):
    """액세스 토큰 발급 포트. JWT 라이브러리는 어댑터 뒤에 숨긴다."""

    @abstractmethod
    def issue(self, player_id: int) -> str: ...
