from __future__ import annotations

import json
from pathlib import Path

from hub.app.dtos.monster_dto import ELEMENTS, PASSIVE_KINDS, Monster, MonsterCatalog, Region
from masterdata.app.ports.output.monster_source_port import MonsterSourcePort

_DEFAULT_PATH = Path(__file__).resolve().parents[3] / "resources" / "monsters.json"


class FileMonsterSourceAdapter(MonsterSourcePort):
    """`resources/monsters.json`을 읽고 형식을 검증한다. 잘못된 파일은 기동 시점이 아니라 첫 호출에 드러난다."""

    def __init__(self, path: Path | None = None) -> None:
        self._path = path or _DEFAULT_PATH

    async def load(self) -> MonsterCatalog:
        raw = json.loads(self._path.read_text(encoding="utf-8"))
        regions = tuple(
            Region(
                id=r["id"], name=r["name"], stage_from=int(r["stageFrom"]),
                stage_to=None if r["stageTo"] is None else int(r["stageTo"]),
                completion_kind=r["completionBonus"]["kind"],
                completion_value=float(r["completionBonus"]["value"]),
            )
            for r in raw["regions"]
        )
        monsters = tuple(
            Monster(
                id=int(m["id"]), name=m["name"], region=m["region"], element=m["element"],
                rarity=float(m["rarity"]), passive_kind=m["passive"]["kind"],
                passive_per_star=float(m["passive"]["perStar"]),
            )
            for m in raw["monsters"]
        )
        region_ids = {r.id for r in regions}
        for m in monsters:
            if m.region not in region_ids:
                raise ValueError(f"몬스터 {m.id}의 지역 {m.region}이 없습니다")
            if m.element not in ELEMENTS or m.passive_kind not in PASSIVE_KINDS:
                raise ValueError(f"몬스터 {m.id}의 속성/패시브 종류가 올바르지 않습니다")
        return MonsterCatalog(version=int(raw["version"]), regions=regions, monsters=monsters)
