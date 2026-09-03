from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class CodexEntryOrm(Base):
    """플레이어의 도감 등록 1건. 전생해도 남는 영구 축(GAME_DESIGN 2장)이라 세이브 JSON 밖에 둔다."""

    __tablename__ = "codex_entries"
    __table_args__ = (UniqueConstraint("player_id", "monster_id", name="uq_codex_entries_player_monster"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # 타입을 명시한다 — `players`는 auth 소유(스포크 직접 참조 금지).
    player_id: Mapped[int] = mapped_column(Integer, ForeignKey("players.id"), index=True)
    monster_id: Mapped[int] = mapped_column(Integer)
    stars: Mapped[int] = mapped_column(Integer)
    captured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
