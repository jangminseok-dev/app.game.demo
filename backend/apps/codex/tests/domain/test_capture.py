from codex.domain.capture import CodexRow, pity_threshold, roll_captures
from codex.tests.support import CATALOG, SeqRng
from hub.app.dtos.codex_dto import KillReport

PITY = 400


def _roll(report, current=None, rate=0.005, rng=None, boss_mult=4.0, max_stars=5, pity=PITY):
    return roll_captures(report, current or {}, rate, CATALOG, boss_mult, max_stars, pity, rng or SeqRng([]))


def test_확률에_걸리면_성급이_오르고_이벤트가_난다():
    # 슬라임(희귀도 1.0) 3마리: 첫 굴림만 성공(0.001 < 0.005)
    changed, events = _roll(KillReport(normal={1: 3}, boss={}), rng=SeqRng([0.001, 0.9, 0.9]))
    assert changed == {1: CodexRow(stars=1, pity_kills=2)}, "포획 후 카운트는 0에서 다시 2마리"
    assert len(events) == 1 and events[0].first is True and events[0].stars == 1 and events[0].by_pity is False


def test_실패한_처치는_천장_카운트로_쌓인다():
    changed, events = _roll(KillReport(normal={1: 5}, boss={}))
    assert changed == {1: CodexRow(stars=0, pity_kills=5)}
    assert events == ()


def test_천장에_닿으면_확정_포획():
    changed, events = _roll(KillReport(normal={1: 1}, boss={}), current={1: CodexRow(0, PITY - 1)})
    assert changed == {1: CodexRow(stars=1, pity_kills=0)}
    assert events[0].by_pity is True and events[0].first is True


def test_천장은_희귀도에_반비례():
    assert pity_threshold(PITY, 1.0) == 400
    assert pity_threshold(PITY, 0.5) == 800
    assert pity_threshold(PITY, 0.3) == 1333
    # 골렘(0.3): 799마리로는 안 되고 1333에서 확정
    _, no = _roll(KillReport(normal={4: 1}, boss={}), current={4: CodexRow(0, 1331)})
    _, yes = _roll(KillReport(normal={4: 1}, boss={}), current={4: CodexRow(0, 1332)})
    assert no == () and yes[0].by_pity is True


def test_희귀도가_확률을_낮춘다():
    # 골렘(희귀도 0.3): p = 0.005 × 0.3 = 0.0015. 0.002는 실패, 0.001은 성공
    _, miss = _roll(KillReport(normal={4: 1}, boss={}), rng=SeqRng([0.002]))
    _, hit = _roll(KillReport(normal={4: 1}, boss={}), rng=SeqRng([0.001]))
    assert miss == () and len(hit) == 1


def test_보스는_배율이_붙는다():
    # 슬라임 보스: p = 0.005 × 4 = 0.02. 0.015는 일반이면 실패, 보스면 성공
    _, normal = _roll(KillReport(normal={1: 1}, boss={}), rng=SeqRng([0.015]))
    _, boss = _roll(KillReport(normal={}, boss={1: 1}), rng=SeqRng([0.015]))
    assert normal == () and len(boss) == 1


def test_성급_상한에서는_굴리지도_세지도_않는다():
    changed, events = _roll(KillReport(normal={1: 5}, boss={}), current={1: CodexRow(5, 0)}, rng=SeqRng([0.0] * 5))
    assert changed == {} and events == ()


def test_중복_포획은_first가_아니다():
    changed, events = _roll(KillReport(normal={1: 2}, boss={}), current={1: CodexRow(2, 10)}, rng=SeqRng([0.0, 0.0]))
    assert changed == {1: CodexRow(4, 0)}
    assert [e.first for e in events] == [False, False]
    assert [e.stars for e in events] == [3, 4]


def test_모르는_몬스터는_무시한다():
    changed, events = _roll(KillReport(normal={999: 10}, boss={}), rng=SeqRng([0.0] * 10))
    assert changed == {} and events == ()
