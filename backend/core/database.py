from __future__ import annotations

import logging
from collections.abc import AsyncGenerator

from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from core.config import DATABASE_URL

logger = logging.getLogger("uvicorn.error")


class Base(DeclarativeBase):
    pass


engine: AsyncEngine | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None


def init_engine() -> None:
    global engine, _session_factory
    if engine is not None:
        return
    engine = create_async_engine(DATABASE_URL, pool_pre_ping=True, echo=False)
    _session_factory = async_sessionmaker(engine, expire_on_commit=False, autoflush=False)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    if _session_factory is None:
        init_engine()
    assert _session_factory is not None
    async with _session_factory() as session:
        yield session


async def ping() -> bool:
    """`SELECT 1` — /health 전용. 실패 원인은 응답에 싣지 않는다(공개 엔드포인트)."""
    if engine is None:
        return False
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception:
        logger.exception("DB 헬스체크 실패")
        return False


async def dispose_engine() -> None:
    global engine, _session_factory
    if engine is not None:
        await engine.dispose()
    engine = None
    _session_factory = None
