from dataclasses import dataclass


@dataclass(frozen=True)
class CodexEntry:
    """도감 행. `stars == 0`이면 아직 미등록이지만 천장 카운트(`pity_kills`)가 쌓이는 중이다."""

    monster_id: int
    stars: int  # 0~5
    pity_kills: int = 0  # 마지막 포획 이후 처치 수 — 천장(확정 포획)까지의 진행


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
    by_pity: bool = False  # 천장으로 확정 포획됐는지


@dataclass(frozen=True)
class KillReport:
    """동기화 한 번에 보고된 처치 수. 키는 몬스터 id."""

    normal: dict[int, int]
    boss: dict[int, int]

    @property
    def total(self) -> int:
        return sum(self.normal.values()) + sum(self.boss.values())
