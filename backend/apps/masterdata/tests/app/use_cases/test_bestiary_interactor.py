from hub.app.dtos.monster_dto import Monster, MonsterCatalog, Region
from masterdata.app.dtos.bestiary_dto import BestiaryQuery
from masterdata.app.use_cases.bestiary_interactor import BestiaryInteractor

CATALOG = MonsterCatalog(
    version=4,
    regions=(Region("forest", "숲", 1, None, "attack", 20),),
    monsters=(Monster(1, "슬라임", "forest", "neutral", 1.0, "gold", 0.5),),
)


class _StubSource:
    async def load(self):
        return CATALOG


async def test_버전이_같으면_unchanged_아니면_표를_준다():
    sut = BestiaryInteractor(source=_StubSource())
    assert (await sut.fetch(BestiaryQuery(client_version=4))).unchanged is True
    r = await sut.fetch(BestiaryQuery(client_version=None))
    assert r.unchanged is False and r.catalog.monsters[0].name == "슬라임"
