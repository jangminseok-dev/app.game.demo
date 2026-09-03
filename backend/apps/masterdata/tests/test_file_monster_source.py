from masterdata.adapter.outbound.file.file_monster_source_adapter import FileMonsterSourceAdapter


async def test_몬스터_30종_지역_3개_기획서_7장():
    c = await FileMonsterSourceAdapter().load()
    assert len(c.monsters) == 30
    assert [r.id for r in c.regions] == ["forest", "cave", "volcano"]
    for r in c.regions:
        assert len(c.monsters_in(r.id)) == 10
    assert len({m.id for m in c.monsters}) == 30, "id 중복"
    assert len({m.name for m in c.monsters}) == 30, "이름 중복"


async def test_스테이지_지역_매핑과_순환():
    c = await FileMonsterSourceAdapter().load()
    assert c.region_for_stage(1).id == "forest"
    assert c.region_for_stage(50).id == "forest"
    assert c.region_for_stage(51).id == "cave"
    assert c.region_for_stage(120).id == "cave"
    assert c.region_for_stage(121).id == "volcano"
    assert c.region_for_stage(9999).id == "volcano"
    assert c.monster_for_stage(1).id == 1
    assert c.monster_for_stage(10).id == 10
    assert c.monster_for_stage(11).id == 1
    assert c.monster_for_stage(51).id == 11
    assert c.monster_for_stage(121).id == 21


async def test_속성_5종이_모두_쓰인다():
    c = await FileMonsterSourceAdapter().load()
    assert {m.element for m in c.monsters} == {"fire", "water", "earth", "wind", "neutral"}
    assert {m.passive_kind for m in c.monsters} == {"attack", "gold", "attackSpeed", "crit", "capture"}
