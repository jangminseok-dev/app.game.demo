from dataclasses import dataclass

# 패시브 종류. 값의 단위는 전부 % — attack·gold·attackSpeed·capture는 배율 %, crit은 %p.
PASSIVE_KINDS = ("attack", "gold", "attackSpeed", "crit", "capture")
ELEMENTS = ("fire", "water", "earth", "wind", "neutral")


@dataclass(frozen=True)
class Region:
    id: str
    name: str
    stage_from: int
    stage_to: int | None  # None이면 마지막 지역(무한)
    completion_kind: str
    completion_value: float


@dataclass(frozen=True)
class Monster:
    id: int
    name: str
    region: str
    element: str
    rarity: float  # 포획률 배율 (1.0 흔함 · 0.6 · 0.3 희귀)
    passive_kind: str
    passive_per_star: float


@dataclass(frozen=True)
class MonsterCatalog:
    version: int
    regions: tuple[Region, ...]
    monsters: tuple[Monster, ...]

    def region_for_stage(self, stage: int) -> Region:
        for r in self.regions:
            if r.stage_from <= stage and (r.stage_to is None or stage <= r.stage_to):
                return r
        return self.regions[-1]

    def monsters_in(self, region_id: str) -> tuple[Monster, ...]:
        return tuple(m for m in self.monsters if m.region == region_id)

    def monster_for_stage(self, stage: int) -> Monster:
        """스테이지의 몬스터 — 지역 안에서 순환한다. 클라이언트 `MonsterCatalog.forStage`와 같다."""
        region = self.region_for_stage(stage)
        pool = self.monsters_in(region.id)
        return pool[(stage - region.stage_from) % len(pool)]

    def by_id(self, monster_id: int) -> Monster | None:
        for m in self.monsters:
            if m.id == monster_id:
                return m
        return None
