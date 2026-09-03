from codex.adapter.outbound.gateways.codex_gateway import CodexGateway
from codex.tests.support import SeqRng, StubBalance, StubCatalog, StubEntries
from hub.app.dtos.codex_dto import CodexEntry, KillReport


def _sut(entries, rng=None):
    return CodexGateway(entries=entries, catalog=StubCatalog(), balance=StubBalance(), rng=rng or SeqRng([]))


async def test_처치_보고를_받아_포획을_굴리고_바뀐_것만_저장한다():
    entries = StubEntries({1: 1})
    events = await _sut(entries, SeqRng([0.0, 0.9, 0.9])).register_kills(
        1, KillReport(normal={1: 2, 2: 1}, boss={}), capture_rate=0.005
    )
    assert [(e.monster_id, e.stars, e.first) for e in events] == [(1, 2, False)]
    assert entries.writes == [{1: 2}]


async def test_처치가_없으면_아무것도_안_한다():
    entries = StubEntries()
    assert await _sut(entries).register_kills(1, KillReport(normal={}, boss={}), 0.005) == ()
    assert entries.writes == []


async def test_도감_목록과_패시브_합계():
    sut = _sut(StubEntries({3: 2, 1: 1}))
    assert await sut.get_entries(1) == (CodexEntry(1, 1), CodexEntry(3, 2))
    p = await sut.get_passives(1)
    assert p.gold == 0.5 and p.crit == 0.4


async def test_빈_도감은_카탈로그를_읽지_않고_0을_준다():
    assert (await _sut(StubEntries()).get_passives(1)).is_empty
