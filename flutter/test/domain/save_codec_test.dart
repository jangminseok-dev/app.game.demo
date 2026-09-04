import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/monster_unit.dart';
import 'package:idle_fantasy/domain/save_codec.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

void main() {
  const config = BalanceConfig();

  test('JSON 왕복 후 상태가 같다', () {
    final original = GameState.initial(config).copyWith(
      stage: 17,
      highestStage: 20,
      gold: 12345.678,
      levels: const {UpgradeType.attack: 5, UpgradeType.goldGain: 2},
      wave: const [MonsterUnit(key: 3, id: 7, hp: 3.5, maxHp: 3.5)],
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
}
