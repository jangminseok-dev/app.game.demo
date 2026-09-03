from dataclasses import dataclass


@dataclass(frozen=True)
class CodexEntry:
    monster_id: int
    stars: int  # 1~5


@dataclass(frozen=True)
class Passives:
    """도감 패시브 합계(%). 합연산 — GAME_DESIGN 7장 1번. 종류 간에는 곱으로 적용된다."""

    attack: float = 0.0
    gold: float = 0.0
    attack_speed: float = 0.0
    crit: float = 0.0  # %p
    capture: float = 0.0

    @property
    def is_empty(self) -> bool:
        return not any((self.attack, self.gold, self.attack_speed, self.crit, self.capture))


@dataclass(frozen=True)
class CaptureEvent:
    monster_id: int
    stars: int  # 포획 후 성급
    first: bool  # 이번에 처음 등록됐는지


@dataclass(frozen=True)
class KillReport:
    """동기화 한 번에 보고된 처치 수. 키는 몬스터 id."""

    normal: dict[int, int]
    boss: dict[int, int]

    @property
    def total(self) -> int:
        return sum(self.normal.values()) + sum(self.boss.values())
