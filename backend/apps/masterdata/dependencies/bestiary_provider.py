from __future__ import annotations

from hub.app.ports.output.monster_catalog_port import MonsterCatalogPort
from masterdata.adapter.outbound.file.file_monster_source_adapter import FileMonsterSourceAdapter
from masterdata.adapter.outbound.gateways.monster_catalog_gateway import MonsterCatalogGateway
from masterdata.app.ports.input.bestiary_use_case import BestiaryUseCase
from masterdata.app.use_cases.bestiary_interactor import BestiaryInteractor


def get_bestiary_use_case() -> BestiaryUseCase:
    return BestiaryInteractor(source=FileMonsterSourceAdapter())


def get_monster_catalog_gateway() -> MonsterCatalogPort:
    """허브 `get_monster_catalog_port`에 main.py가 바인딩한다."""
    return MonsterCatalogGateway(source=FileMonsterSourceAdapter())
