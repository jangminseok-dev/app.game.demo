import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
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
      monsterHp: 3.5,
      isBoss: true,
      bossTimeLeft: 12.3,
      killsOnStage: 10,
      attackTimer: 0.42,
      totalKills: 999,
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
