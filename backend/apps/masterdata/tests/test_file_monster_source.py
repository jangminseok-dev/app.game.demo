from masterdata.adapter.outbound.file.file_monster_source_adapter import FileMonsterSourceAdapter


async def test_몬스터_100종_지역_10개_기획서_7장():
    c = await FileMonsterSourceAdapter().load()
    assert len(c.monsters) == 100
    assert [r.id for r in c.regions] == [
        "forest", "cave", "volcano", "tundra", "swamp", "desert", "abyss", "sky", "ruins", "demon"
    ]
    for r in c.regions:
        assert len(c.monsters_in(r.id)) == 10
    assert len({m.id for m in c.monsters}) == 100, "id 중복"
    assert len({m.name for m in c.monsters}) == 100, "이름 중복"
    # 지역 범위는 빈틈·겹침 없이 이어진다
    for a, b in zip(c.regions, c.regions[1:]):
        assert a.stage_to is not None and b.stage_from == a.stage_to + 1
    assert c.regions[-1].stage_to is None


async def test_도감_패시브_총합_상한_기획서_7장_3번():
    """전부 ★5 + 전 지역 완성이어도 종류별 합이 300%를 넘지 않는다 — 수집이 전직·전생을 압도하지 않게."""
    c = await FileMonsterSourceAdapter().load()
    totals: dict[str, float] = {}
    for m in c.monsters:
        totals[m.passive_kind] = totals.get(m.passive_kind, 0) + m.passive_per_star * 5
    for r in c.regions:
        totals[r.completion_kind] = totals.get(r.completion_kind, 0) + r.completion_value
    assert all(v <= 300 for v in totals.values()), totals


async def test_스테이지_지역_매핑과_순환():
    c = await FileMonsterSourceAdapter().load()
    assert c.region_for_stage(1).id == "forest"
    assert c.region_for_stage(50).id == "forest"
    assert c.region_for_stage(51).id == "cave"
    assert c.region_for_stage(120).id == "cave"
    assert c.region_for_stage(121).id == "volcano"
    assert c.region_for_stage(200).id == "volcano"
    assert c.region_for_stage(201).id == "tundra"
    assert c.region_for_stage(1101).id == "demon"
    assert c.region_for_stage(9999).id == "demon"
    assert c.monster_for_stage(1).id == 1
    assert c.monster_for_stage(10).id == 10
    assert c.monster_for_stage(11).id == 1
    assert c.monster_for_stage(51).id == 11
    assert c.monster_for_stage(121).id == 21
    assert c.monster_for_stage(1110).id == 100


async def test_속성_5종이_모두_쓰인다():
    c = await FileMonsterSourceAdapter().load()
    assert {m.element for m in c.monsters} == {"fire", "water", "earth", "wind", "neutral"}
    assert {m.passive_kind for m in c.monsters} == {"attack", "gold", "attackSpeed", "crit", "capture"}
