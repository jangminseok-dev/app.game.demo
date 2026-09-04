import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/equipment.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);
  final rng = Random(2);

  GameState withStones(int stones, {int stage = 1, int craftLevel = 0}) =>
      GameState.initial(config).copyWith(
        stage: stage,
        equipment: EquipmentState(stones: stones, craftLevel: craftLevel),
      );

  test('강화석을 내고 장비를 만든다', () {
    final s = withStones(1000);
    final cost = s.equipment.craftCost(config);
    final (next, made) = engine.craft(s, rng)!;
    expect(next.equipment.stones, 1000 - cost);
    expect(next.equipment.craftLevel, 1, reason: '두드리면 숙련도가 오른다');
    expect(next.equipment.equipped[made.slot], made, reason: '빈 부위면 바로 입는다');
  });

  test('강화석이 모자라면 못 만든다', () {
    expect(engine.craft(withStones(0), rng), isNull);
  });

  test('숙련도가 오를수록 비싸진다', () {
    final cheap = withStones(1000).equipment.craftCost(config);
    final dear = withStones(1000, craftLevel: 20).equipment.craftCost(config);
    expect(dear, greaterThan(cheap));
  });

  test('티어는 지금 층을 따른다', () {
    final (_, made) = engine.craft(withStones(9999, stage: 120), rng)!;
    expect(made.tier, (120 - 1) ~/ config.equipStagesPerTier);
  });

  test('숙련도가 높으면 좋은 등급이 더 자주 나온다', () {
    int legendaryCount(int craftLevel) {
      var s = withStones(1000000, craftLevel: craftLevel);
      var count = 0;
      final r = Random(7);
      for (var i = 0; i < 400; i++) {
        final result = engine.craft(s.copyWith(equipment: s.equipment.copyWith(craftLevel: craftLevel)), r);
        if (result == null) break;
        s = result.$1;
        if (result.$2.grade.index >= EquipGrade.epic.index) count++;
      }
      return count;
    }

    expect(legendaryCount(30), greaterThan(legendaryCount(0)));
  });

  test('강화석은 강화와 제작 두 곳에 쓰인다', () {
    final s = withStones(1000);
    expect(s.equipment.canEnhance, isTrue);
    expect(s.equipment.canCraft(config), isTrue);
  });

  test('숙련도는 저장된다', () {
    final s = withStones(10, craftLevel: 7);
    expect(decodeState(encodeState(s))!.equipment.craftLevel, 7);
  });

  test('대장간 이전 저장도 읽힌다', () {
    final j = encodeState(GameState.initial(config));
    (j['equipment'] as Map<String, dynamic>).remove('craftLevel');
    expect(decodeState(j)!.equipment.craftLevel, 0);
  });
}
