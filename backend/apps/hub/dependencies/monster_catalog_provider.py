from __future__ import annotations

from hub.app.ports.output.monster_catalog_port import MonsterCatalogPort


def get_monster_catalog_port() -> MonsterCatalogPort:
    raise NotImplementedError("MonsterCatalogPort는 main.py에서 masterdata 게이트웨이로 주입된다")
