"""세이브 델타 검증 — GAME_DESIGN 12장.

직전 서버 상태 → 새 상태의 변화가 경과 시간 안에 물리적으로 가능한지 본다.
정밀 시뮬레이션이 아니라 **상한 검사**다: 정직한 플레이는 절대 걸리지 않고,
조작은 상한 배수 이상 이득을 못 본다. 상한이 느슨한 만큼 오탐이 없다.
"""

from __future__ import annotations

from dataclasses import dataclass

from hub.app.dtos.balance_dto import Balance
from hub.app.dtos.codex_dto import Passives
from save.domain.balance.formulas import NO_PASSIVES, boss_gold_reward, stats_of, upgrade_cost
from save.domain.snapshot import Snapshot

# 처치 수 상한 여유 — 클라이언트 틱 오차·치명타 편차를 흡수한다.
KILL_SLACK = 1.5
# 광역 스킬이 초당 더 잡을 수 있는 최대 마릿수.
#
# 스킬은 장착 3칸이고 칸마다 대기 시간이 있다. 가장 유리한 조합(회전베기 5/10초,
# 유성 5/20초, 서리 3/14초)이 초당 약 0.96마리다. 여기에 여유를 조금 더 둔다.
# 스킬 구성은 서버가 모르므로 최댓값으로 잡는다 — 정직한 플레이가 걸리면 안 된다.
MAX_SKILL_KILLS_PER_SECOND = 1.2
# 아주 짧은 동기화 간격에서 0으로 수렴하는 것을 막는 최소 인정 시간(초).
MIN_ELAPSED = 5.0


@dataclass(frozen=True)
class Violation:
    rule: str
    detail: str


def validate(
    prev: Snapshot, new: Snapshot, elapsed_seconds: float, b: Balance, p: Passives = NO_PASSIVES
) -> Violation | None:
    elapsed = max(elapsed_seconds, MIN_ELAPSED)
    stats = stats_of(new, b, p)

    # 1. 되돌아갈 수 없는 값들 — 레벨·최고 스테이지·누적 처치는 줄지 않는다.
    for upgrade, level in prev.levels.items():
        if new.level(upgrade) < level:
            return Violation("level_decreased", f"{upgrade} {level}→{new.level(upgrade)}")
    if new.highest_stage < prev.highest_stage:
        return Violation("highest_stage_decreased", f"{prev.highest_stage}→{new.highest_stage}")
    if new.total_kills < prev.total_kills:
        return Violation("kills_decreased", f"{prev.total_kills}→{new.total_kills}")

    # 2. 처치 수 ≤ 경과 시간 × (공격속도 + 광역 스킬 상한).
    #    평타는 한 마리에 한 번은 때려야 하고, 스킬은 한 번에 여러 마리를 때린다.
    kills_delta = new.total_kills - prev.total_kills
    max_kills = elapsed * (stats.attacks_per_second + MAX_SKILL_KILLS_PER_SECOND) * KILL_SLACK + 1
    if kills_delta > max_kills:
        return Violation("too_many_kills", f"{kills_delta} > {max_kills:.0f} ({elapsed:.0f}s)")

    # 2-1. 포획 판정용 처치 보고는 누적 처치 증가분을 넘을 수 없다.
    reported = new.kill_report.total
    if reported > kills_delta:
        return Violation("kill_report_exceeds_delta", f"{reported} > {kills_delta}")

    # 3. 골드 보존: 새 골드 + 쓴 골드 ≤ 이전 골드 + 벌 수 있는 최대 골드.
    #    벌이 상한은 "모든 처치가 최고 스테이지 보스였다"는 가정(×10 여유)이다.
    spent = 0.0
    for upgrade, level in new.levels.items():
        for lv in range(prev.level(upgrade), level):
            spent += upgrade_cost(upgrade, lv, b)
    earned_max = kills_delta * boss_gold_reward(new.highest_stage, b) * stats.gold_multiplier
    if new.gold + spent > prev.gold + earned_max + 1e-6:
        return Violation(
            "gold_conservation",
            f"gold {new.gold:.0f} + spent {spent:.0f} > prev {prev.gold:.0f} + max {earned_max:.0f}",
        )
    return None
