from masterdata.app.dtos.balance_dto import BalanceQuery
from masterdata.app.ports.output.balance_source_port import BalanceRecord
from masterdata.app.use_cases.balance_interactor import BalanceInteractor

RECORD = BalanceRecord(
    version=3,
    monster_hp_base=10,
    monster_hp_growth=1.18,
    boss_hp_multiplier=10,
    boss_time_limit=30,
    gold_base=5,
    gold_growth=1.15,
    boss_gold_multiplier=10,
    upgrade_cost_growth=1.09,
    kills_per_stage=10,
    crit_multiplier=2.0,
    offline_cap_seconds=28800,
    offline_efficiency=0.5,
    offline_min_seconds=60,
    boss_capture_multiplier=4.0,
    max_stars=5,
)


class _StubSource:
    async def load(self):
        return RECORD


async def test_계수를_그대로_내려준다():
    r = await BalanceInteractor(source=_StubSource()).fetch(BalanceQuery(client_version=None))
    assert r.version == 3
    assert r.monster_hp_growth == 1.18
    assert r.unchanged is False


async def test_클라이언트_버전이_같으면_unchanged():
    r = await BalanceInteractor(source=_StubSource()).fetch(BalanceQuery(client_version=3))
    assert r.unchanged is True


async def test_클라이언트_버전이_낡으면_새_계수():
    r = await BalanceInteractor(source=_StubSource()).fetch(BalanceQuery(client_version=2))
    assert r.unchanged is False
    assert r.version == 3
