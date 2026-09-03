"""전역 비밀값(루트 `.env`) 관리자 — 프로젝트의 모든 `.env` 로드는 여기를 통과한다.

앱 런타임(`core/config.py`)·마이그레이션(`alembic/env.py`)·스크립트가 전부 이 모듈을 쓰고,
개별 모듈은 `load_dotenv`·`os.getenv`를 직접 부르지 않는다.
이미 `os.environ`에 있는 값은 덮어쓰지 않는다 — 컨테이너 주입이 파일보다 우선.
"""

from __future__ import annotations

import os
from pathlib import Path


def default_env_path() -> Path:
    """저장소 루트 `.env` — 이 파일: `backend/core/key/secret_manager.py` 기준."""
    return Path(__file__).resolve().parents[3] / ".env"


class SecretManager:
    _instance: SecretManager | None = None

    def __init__(self, env_path: Path | None = None) -> None:
        self._env_path = env_path or default_env_path()
        self._loaded = False

    @classmethod
    def instance(cls, env_path: Path | None = None) -> SecretManager:
        if cls._instance is None:
            cls._instance = cls(env_path=env_path)
        return cls._instance

    @classmethod
    def reset_instance(cls) -> None:
        cls._instance = None

    def load_env(self) -> None:
        if self._loaded:
            return
        from dotenv import load_dotenv

        load_dotenv(self._env_path)
        self._loaded = True

    def get(self, name: str, default: str = "") -> str:
        self.load_env()
        return (os.getenv(name) or default).strip()

    def require(self, name: str) -> str:
        value = self.get(name)
        if not value:
            raise RuntimeError(f"{name} 미설정 — 루트 .env를 확인하세요 ({self._env_path})")
        return value


def get_secret_manager(env_path: Path | None = None) -> SecretManager:
    return SecretManager.instance(env_path=env_path)
