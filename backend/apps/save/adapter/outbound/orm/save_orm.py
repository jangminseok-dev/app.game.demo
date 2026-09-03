from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, ForeignKey, Integer, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class SaveOrm(Base):
    """플레이어당 세이브 1건. `state`는 클라이언트 형식 그대로, `synced_at`은 서버 시간이다."""

    __tablename__ = "saves"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # 타입을 명시한다 — `players`는 auth 소유라 save만 로드하면 FK가 타입을 못 찾는다.
    player_id: Mapped[int] = mapped_column(Integer, ForeignKey("players.id"), unique=True, index=True)
    state: Mapped[dict[str, Any]] = mapped_column(JSONB)
    synced_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
