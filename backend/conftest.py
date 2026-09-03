"""테스트 공용 env — `core.config`가 import 시점에 요구하는 필수 키의 테스트 기본값.

`.env`가 있으면 그 값이 우선한다(secret manager는 os.environ을 덮어쓰지 않는다).
단위 테스트는 DB에 붙지 않으므로 DATABASE_URL은 형식만 맞으면 된다.
"""

import os

os.environ.setdefault("DATABASE_URL", "postgresql://test:test@127.0.0.1:1/test")
os.environ.setdefault("JWT_SECRET", "test-secret-not-for-production-0123456789")
