from codex.adapter.outbound.gateways.codex_gateway import CodexGateway
from codex.domain.capture import CodexRow
from codex.tests.support import SeqRng, StubBalance, StubCatalog, StubEntries
from hub.app.dtos.codex_dto import CodexEntry, KillReport


def _sut(entries, rng=None):
    return CodexGateway(entries=entries, catalog=StubCatalog(), balance=StubBalance(), rng=rng or SeqRng([]))


async def test_처치_보고를_받아_포획을_굴리고_바뀐_것만_저장하고_도감_전체를_돌려준다():
    entries = StubEntries({1: CodexRow(1, 0)})
    events, codex = await _sut(entries, SeqRng([0.0, 0.9, 0.9])).register_kills(
        1, KillReport(normal={1: 2, 2: 1}, boss={}), capture_rate=0.005
    )
    assert [(e.monster_id, e.stars, e.first) for e in events] == [(1, 2, False)]
    assert entries.writes == [{1: CodexRow(2, 1), 2: CodexRow(0, 1)}]
    assert codex == (CodexEntry(1, 2, 1), CodexEntry(2, 0, 1))


async def test_처치가_없으면_굴리지_않고_현재_도감만_돌려준다():
    entries = StubEntries({3: CodexRow(1, 5)})
    events, codex = await _sut(entries).register_kills(1, KillReport(normal={}, boss={}), 0.005)
    assert events == () and codex == (CodexEntry(3, 1, 5),)
    assert entries.writes == []


async def test_도감_목록과_패시브_합계_미등록행은_패시브에_안_들어간다():
    sut = _sut(StubEntries({3: CodexRow(2, 0), 1: CodexRow(1, 3), 2: CodexRow(0, 40)}))
    assert await sut.get_entries(1) == (CodexEntry(1, 1, 3), CodexEntry(2, 0, 40), CodexEntry(3, 2, 0))
    p = await sut.get_passives(1)
    assert p.gold == 0.5 and p.crit == 0.4 and p.attack_speed == 0


async def test_빈_도감은_카탈로그를_읽지_않고_0을_준다():
    assert (await _sut(StubEntries()).get_passives(1)).is_empty
