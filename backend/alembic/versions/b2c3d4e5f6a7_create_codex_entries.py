"""codex_entries 테이블 (6주차 — 도감)

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-09-03

도감은 전생해도 남는 영구 축이라 세이브 JSON이 아니라 테이블에 둔다. 플레이어당 몬스터당 1행, 성급 1~5.
"""

from collections.abc import Sequence
from typing import Union

import sqlalchemy as sa
from alembic import op

revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "codex_entries",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("player_id", sa.Integer(), nullable=False),
        sa.Column("monster_id", sa.Integer(), nullable=False),
        sa.Column("stars", sa.Integer(), nullable=False),
        sa.Column("captured_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["player_id"], ["players.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("player_id", "monster_id", name="uq_codex_entries_player_monster"),
    )
    op.create_index("ix_codex_entries_player_id", "codex_entries", ["player_id"])


def downgrade() -> None:
    op.drop_index("ix_codex_entries_player_id", table_name="codex_entries")
    op.drop_table("codex_entries")
