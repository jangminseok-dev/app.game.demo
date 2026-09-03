from codex.domain.passives import compute_passives, region_completion
from codex.tests.support import CATALOG


def test_성급마다_perStar를_더한다_합연산():
    p = compute_passives({1: 3, 3: 2}, CATALOG)
    assert p.gold == 1.5  # 슬라임 0.5 × 3
    assert p.crit == 0.4  # 박쥐 0.2 × 2
    assert p.attack == 0 and p.attack_speed == 0


def test_지역을_전부_등록하면_완성_보너스():
    p = compute_passives({1: 1, 2: 1}, CATALOG)
    assert p.attack == 20  # 숲 완성
    assert p.gold == 0.5
    incomplete = compute_passives({1: 5}, CATALOG)
    assert incomplete.attack == 0


def test_빈_도감은_전부_0():
    assert compute_passives({}, CATALOG).is_empty


def test_지역_완성률():
    assert region_completion({1: 2, 3: 1}, CATALOG) == {"forest": (1, 2), "cave": (1, 2)}
