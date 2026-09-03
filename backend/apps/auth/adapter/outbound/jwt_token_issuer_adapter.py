from __future__ import annotations

from datetime import UTC, datetime, timedelta

import jwt

from auth.app.ports.output.token_issuer_port import TokenIssuerPort
from core.config import JWT_ACCESS_TTL_SECONDS, JWT_SECRET
from core.security import JWT_ALGORITHM


class JwtTokenIssuerAdapter(TokenIssuerPort):
    def __init__(self, secret: str = JWT_SECRET, ttl_seconds: int = JWT_ACCESS_TTL_SECONDS) -> None:
        self._secret = secret
        self._ttl = timedelta(seconds=ttl_seconds)

    def issue(self, player_id: int) -> str:
        now = datetime.now(UTC)
        payload = {"sub": str(player_id), "iat": now, "exp": now + self._ttl}
        return jwt.encode(payload, self._secret, algorithm=JWT_ALGORITHM)
