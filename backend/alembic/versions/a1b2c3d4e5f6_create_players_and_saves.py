"""players · saves 테이블 (4~5주차 — 게스트 계정 + 클라우드 세이브)

Revision ID: a1b2c3d4e5f6
Revises:
Create Date: 2026-09-03

players는 auth 소유, saves는 save 소유다. saves.state는 클라이언트 세이브 형식 그대로(JSONB)이고
서버는 검증에 필요한 필드만 읽는다. synced_at은 서버 시간 — 오프라인 보상과 델타 검증의 기준.
"""

from collections.abc import Sequence
from typing import Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "players",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_players_device_id", "players", ["device_id"], unique=True)

    op.create_table(
        "saves",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("player_id", sa.Integer(), nullable=False),
        sa.Column("state", postgresql.JSONB(), nullable=False),
        sa.Column("synced_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["player_id"], ["players.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_saves_player_id", "saves", ["player_id"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_saves_player_id", table_name="saves")
    op.drop_table("saves")
    op.drop_index("ix_players_device_id", table_name="players")
    op.drop_table("players")
