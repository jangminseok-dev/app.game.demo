"""JWT 검증 의존성 — 전 라우터 공용 인증 가드.

발급은 auth 스포크(인터랙터) 몫이고, 여기는 서명 검증 + 계정 존재 확인만 한다.
스포크가 auth를 import하면 스타 토폴로지 위반이므로 순수 인프라(core)에 둔다.
"""

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import JWT_SECRET
from core.database import get_db

_bearer = HTTPBearer(auto_error=False)

# 허용 알고리즘은 리터럴 고정 — 설정으로 빼지 않는다(알고리즘 혼동 공격 방지).
JWT_ALGORITHM = "HS256"


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_current_player_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: AsyncSession = Depends(get_db),
) -> int:
    """Authorization: Bearer <jwt> → players.id.

    매 요청 players PK 조회 1회 — 삭제된 계정의 기발급 토큰을 즉시 막는다.
    core는 apps ORM을 import할 수 없으므로(스타 토폴로지) 원시 SQL이다.
    """
    if credentials is None:
        raise _unauthorized("인증이 필요합니다.")
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        player_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise _unauthorized("토큰이 유효하지 않습니다.")
    row = (
        await db.execute(text("SELECT 1 FROM players WHERE id = :pid"), {"pid": player_id})
    ).first()
    if row is None:
        raise _unauthorized("유효하지 않은 계정입니다.")
    # 가드 SELECT가 연 트랜잭션을 즉시 닫아 커넥션을 돌려준다.
    await db.rollback()
    return player_id
