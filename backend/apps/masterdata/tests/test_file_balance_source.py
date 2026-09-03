from masterdata.adapter.outbound.file.file_balance_source_adapter import FileBalanceSourceAdapter


async def test_리포지토리의_balance_json이_기획서_4장_계수와_같다():
    r = await FileBalanceSourceAdapter().load()
    assert r.monster_hp_base == 10 and r.monster_hp_growth == 1.18
    assert r.gold_base == 5 and r.gold_growth == 1.15
    assert r.upgrade_cost_growth == 1.09
    # 가장 중요한 원칙 — 보상 성장률 < 요구치 성장률
    assert r.gold_growth < r.monster_hp_growth
    assert r.offline_cap_seconds == 8 * 3600 and r.offline_efficiency == 0.5
    assert r.boss_capture_multiplier == 4.0 and r.max_stars == 5
    assert r.base_capture_rate == 0.005 and r.capture_rate_per_level == 0.0005
    # 천장은 기대값(1/p = 200)의 2배 — 불운 상한 역할
    assert r.capture_pity_kills == round(2 / r.base_capture_rate)
    assert r.attack_base == 10 and r.attack_per_level == 5
    assert set(r.upgrade_base_costs) == {"attack", "attackSpeed", "critChance", "goldGain", "captureRate"}
