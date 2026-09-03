"""런타임 설정 상수. env 키는 전부 여기서 상수로 노출하고 다른 곳에서 `os.getenv`를 쓰지 않는다.

새 키를 추가하면 `.env.example`에도 등록한다.
"""

from core.key.secret_manager import get_secret_manager

_secrets = get_secret_manager()

# `.env`는 드라이버 무관하게 `postgresql://`로 적고, 런타임(asyncpg)과 alembic(psycopg)이 각자 바꿔 쓴다.
DATABASE_URL = _secrets.require("DATABASE_URL").replace("postgresql://", "postgresql+asyncpg://")

# JWT HS256 서명 비밀. 발급(auth)과 검증(core/security)이 같은 프로세스에 있어 대칭키로 충분하다.
# 발급 프로세스를 분리하게 되면 RS256 + 개인키 분리(redoceanmap 방식)로 옮긴다.
JWT_SECRET = _secrets.require("JWT_SECRET")
JWT_ACCESS_TTL_SECONDS = int(_secrets.get("JWT_ACCESS_TTL_SECONDS", "86400"))

ENV = _secrets.get("ENV", "development")
