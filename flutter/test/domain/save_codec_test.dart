import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/field.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/monster_unit.dart';
import 'package:idle_fantasy/domain/save_codec.dart';
import 'package:idle_fantasy/domain/spirit.dart';
import 'package:idle_fantasy/domain/summon.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

import '../support/catalog.dart';

void main() {
  const config = BalanceConfig();

  test('JSON 왕복 후 상태가 같다', () {
    final original = GameState.initial(config).copyWith(
      stage: 17,
      highestStage: 20,
      gold: 12345.678,
      levels: const {UpgradeType.attack: 5, UpgradeType.goldGain: 2},
      wave: const [MonsterUnit(key: 3, id: 7, hp: 3.5, maxHp: 3.5, x: 20, y: heroHomeY)],
      waveSeq: 4,
      isBoss: true,
      bossTimeLeft: 12.3,
      killsOnStage: 10,
      attackTimer: 0.42,
      totalKills: 999,
      killLog: const {7: 3, 8: 1},
      bossKillLog: const {7: 1},
      codex: const {1: 5, 7: 2},
    );
    final savedAt = DateTime(2026, 9, 3, 14, 30, 5);

    final text = jsonEncode(SaveData(state: original, savedAt: savedAt).toJson());
    final restored = SaveData.fromJson(jsonDecode(text) as Map<String, dynamic>)!;

    expect(restored.savedAt, savedAt);
    final s = restored.state;
    expect(s.stage, 17);
    expect(s.highestStage, 20);
    expect(s.gold, 12345.678);
    expect(s.levels, {UpgradeType.attack: 5, UpgradeType.goldGain: 2});
    expect(s.monsterHp, 3.5);
    expect(s.isBoss, true);
    expect(s.bossTimeLeft, 12.3);
    expect(s.killsOnStage, 10);
    expect(s.attackTimer, 0.42);
    expect(s.totalKills, 999);
    expect(s.monsterId, 7);
    expect(s.killLog, {7: 3, 8: 1});
    expect(s.bossKillLog, {7: 1});
    expect(s.codex, {1: 5, 7: 2});
  });

  test('구버전(도감 이전) 저장도 읽힌다', () {
    final json = encodeState(GameState.initial(config))
      ..remove('monsterId')
      ..remove('killLog')
      ..remove('codex');
    final s = decodeState(json)!;
    expect(s.monsterId, 1);
    expect(s.killLog, isEmpty);
    expect(s.codex, isEmpty);
  });

  test('서버 스냅샷 필드명과 같다', () {
    final json = encodeState(GameState.initial(config).copyWith(killLog: const {3: 2}));
    expect(json['killLog'], {'normal': {'3': 2}, 'boss': {}});
    expect(json.keys, containsAll(['stage', 'highestStage', 'gold', 'levels', 'totalKills', 'monsterId', 'killLog']));
  });

  test('버전이 다르면 null', () {
    final json = SaveData(state: GameState.initial(config), savedAt: DateTime.now()).toJson();
    json['version'] = 999;
    expect(SaveData.fromJson(json), isNull);
  });

  test('필드가 빠진 깨진 데이터는 null', () {
    expect(decodeState({'stage': 1}), isNull);
    expect(SaveData.fromJson({'version': 1, 'savedAt': 'x', 'state': {}}), isNull);
  });

  test('모르는 업그레이드 이름은 무시한다', () {
    final json = encodeState(GameState.initial(config));
    json['levels'] = {'attack': 3, 'teleport': 9};
    final s = decodeState(json)!;
    expect(s.levels, {UpgradeType.attack: 3});
  });

  test('소환 상태가 저장에 실린다', () {
    final state = GameState.initial(config).copyWith(
      summon: const SummonState(stones: 120, relics: {RelicSlot.wing: 4}),
    );
    final back = decodeState(encodeState(state))!;
    expect(back.summon.stones, 120);
    expect(back.summon.starsOf(RelicSlot.wing), 4);
  });

  test('정령 상태가 저장에 실린다', () {
    final state = GameState.initial(config).copyWith(
      spirits: const SpiritState(owned: {SpiritId.frost: 4}, active: SpiritId.frost),
    );
    final back = decodeState(encodeState(state))!;
    expect(back.spirits.starsOf(SpiritId.frost), 4);
    expect(back.spirits.active, SpiritId.frost);
  });

  test('40층 저장을 읽으면 3초 안에 무리와 만난다 — heroX가 살아야 거리가 맞는다(2026-09-06 전체 리뷰)', () {
    // 실측 시나리오: heroX 16457, 무리 x 16700대. heroX를 저장에 안 넣으면 로드 직후
    // heroX=0이 되어 무리(16700대)까지 64초를 빈 맵으로 걸어야 한다.
    final engine = BattleEngine(config, catalog: loadBundledCatalog());
    final saved = GameState.initial(config).copyWith(
      stage: 40,
      heroX: 16457,
      heroY: heroHomeY,
      wave: const [
        MonsterUnit(key: 0, id: 1, hp: 10, maxHp: 10, x: 16717, y: heroHomeY),
        MonsterUnit(key: 1, id: 1, hp: 10, maxHp: 10, x: 16743, y: heroHomeY),
        MonsterUnit(key: 2, id: 1, hp: 10, maxHp: 10, x: 16769, y: heroHomeY),
        MonsterUnit(key: 3, id: 1, hp: 10, maxHp: 10, x: 16717, y: heroHomeY),
      ],
    );

    var s = decodeState(encodeState(saved))!;
    var met = false;
    for (var i = 0; i < 60 && !met; i++) {
      s = engine.tick(s, 0.05, Random(1));
      met = s.wave.any(
        (m) => distanceBetween(s.heroX, s.heroY, m.x, m.y) <= config.heroAttackRange * 0.8 + 1,
      );
    }
    expect(met, isTrue, reason: '3초(60틱) 안에 무리 중 하나가 주인공 사거리 안에 들어와야 한다');
  });
}
