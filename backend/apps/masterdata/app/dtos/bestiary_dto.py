from dataclasses import dataclass

from hub.app.dtos.monster_dto import MonsterCatalog


@dataclass(frozen=True)
class BestiaryQuery:
    client_version: int | None


@dataclass(frozen=True)
class BestiaryResponse:
    unchanged: bool
    catalog: MonsterCatalog
