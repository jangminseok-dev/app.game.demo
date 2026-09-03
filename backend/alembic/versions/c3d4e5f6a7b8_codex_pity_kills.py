"""codex_entries.pity_kills — 포획 천장 카운트 (7주차 피드백 반영)

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-09-03

마지막 포획 이후 처치 수. `capture_pity_kills / 희귀도`에 닿으면 확정 포획하고 0으로 되돌린다.
성급 0인 행도 카운트를 위해 존재할 수 있다.
"""

from collections.abc import Sequence
from typing import Union

import sqlalchemy as sa
from alembic import op

revision: str = "c3d4e5f6a7b8"
down_revision: Union[str, Sequence[str], None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "codex_entries", sa.Column("pity_kills", sa.Integer(), server_default="0", nullable=False)
    )


def downgrade() -> None:
    op.drop_column("codex_entries", "pity_kills")
