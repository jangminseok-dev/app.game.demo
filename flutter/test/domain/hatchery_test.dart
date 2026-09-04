import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/dungeon.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/hatchery.dart';
import 'package:idle_fantasy/domain/pet.dart';
import 'package:idle_fantasy/domain/save_codec.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);
  final rng = Random(4);

  /// 알 조각이 넉넉한 상태.
  GameState rich({int shards = 1000}) =>
      GameState.initial(config).copyWith(dungeon: DungeonState(eggShards: shards));

  group('부화', () {
    test('알 조각을 내고 알을 올린다', () {
      final s = engine.startHatch(rich(), 0, EggKind.small)!;
      expect(s.dungeon.eggShards, 1000 - EggKind.small.cost);
      expect(s.hatchery.eggAt(0)?.kind, EggKind.small);
      expect(s.hatchery.eggAt(0)?.ready, isFalse);
    });

    test('조각이 모자라면 못 올린다', () {
      expect(engine.startHatch(rich(shards: 0), 0, EggKind.small), isNull);
    });

    test('이미 알이 있는 칸에는 못 올린다', () {
      final s = engine.startHatch(rich(), 0, EggKind.small)!;
      expect(engine.startHatch(s, 0, EggKind.large), isNull);
      expect(engine.startHatch(s, 1, EggKind.large), isNotNull, reason: '다른 칸은 된다');
    });

    test('시간이 다 되기 전에는 못 꺼낸다', () {
      var s = engine.startHatch(rich(), 0, EggKind.small)!;
      s = s.copyWith(hatchery: s.hatchery.advance(EggKind.small.seconds - 10));
      expect(engine.collectEgg(s, 0, rng), isNull);
    });

    test('시간이 지나면 펫이 나오고 칸이 빈다', () {
      var s = engine.startHatch(rich(), 0, EggKind.small)!;
      s = s.copyWith(hatchery: s.hatchery.advance(EggKind.small.seconds));
      final done = engine.collectEgg(s, 0, rng)!;
      expect(done.pets.owned, hasLength(1));
      expect(done.pets.active, isNotNull, reason: '첫 마리는 자동으로 데리고 다닌다');
      expect(done.hatchery.eggAt(0), isNull);
    });

    test('광고 단축은 남은 시간을 줄인다', () {
      final s = engine.startHatch(rich(), 0, EggKind.large)!;
      final sped = engine.speedUpHatch(s, 0);
      expect(sped.hatchery.eggAt(0)!.remaining,
          closeTo(s.hatchery.eggAt(0)!.remaining - config.adSpeedUpSeconds, 1e-9));
    });

    test('세 칸을 동시에 돌릴 수 있다', () {
      var s = rich();
      for (var i = 0; i < HatcheryState.slots; i++) {
        s = engine.startHatch(s, i, EggKind.small)!;
      }
      expect(s.hatchery.freeEggSlots, 0);
      s = s.copyWith(hatchery: s.hatchery.advance(EggKind.small.seconds));
      expect(s.hatchery.hasReady, isTrue);
    });

    test('긴 알일수록 오래 걸리고 비싸다', () {
      final kinds = EggKind.values;
      for (var i = 1; i < kinds.length; i++) {
        expect(kinds[i].seconds, greaterThan(kinds[i - 1].seconds));
        expect(kinds[i].cost, greaterThan(kinds[i - 1].cost));
        expect(kinds[i].gradeBias, greaterThan(kinds[i - 1].gradeBias));
      }
    });
  });

  group('탐험', () {
    test('보내면 시간이 걸리고 끝나면 골드와 조각을 준다', () {
      var s = engine.sendExpedition(rich().copyWith(highestStage: 40), 0)!;
      expect(engine.collectExpedition(s, 0), isNull, reason: '아직 안 돌아왔다');
      s = s.copyWith(hatchery: s.hatchery.advance(config.expeditionSeconds));
      final done = engine.collectExpedition(s, 0)!;
      expect(done.gold, greaterThan(s.gold));
      expect(done.dungeon.eggShards, s.dungeon.eggShards + config.expeditionShards);
      expect(done.hatchery.expeditionAt(0), isNull);
    });

    test('보상은 보낸 시점의 최고 층으로 정해진다', () {
      var s = engine.sendExpedition(rich().copyWith(highestStage: 10), 0)!;
      s = s.copyWith(highestStage: 500, hatchery: s.hatchery.advance(config.expeditionSeconds));
      final done = engine.collectExpedition(s, 0)!;
      expect(done.gold, closeTo(expeditionGold(10, config), 1e-6),
          reason: '돌아오는 사이에 층을 올려도 보상은 그대로다');
    });

    test('나가 있는 칸에는 또 못 보낸다', () {
      final s = engine.sendExpedition(rich(), 0)!;
      expect(engine.sendExpedition(s, 0), isNull);
    });
  });

  group('펫 능력', () {
    test('데리고 다니는 펫만 능력치에 반영된다', () {
      final base = GameState.initial(config);
      const pet = Pet(grade: PetGrade.legendary, bonus: PetBonus.attack);
      final withPet = base.copyWith(pets: PetState.empty.add(pet));
      expect(withPet.statsWith(config).attack,
          closeTo(base.statsWith(config).attack * (1 + pet.value), 1e-9));
    });

    test('펫을 바꾸면 반영되는 능력도 바뀐다', () {
      var pets = PetState.empty.add(const Pet(grade: PetGrade.rare, bonus: PetBonus.gold));
      pets = pets.add(const Pet(grade: PetGrade.rare, bonus: PetBonus.attack));
      expect(pets.bonusOf(PetBonus.gold), greaterThan(0));
      expect(pets.bonusOf(PetBonus.attack), 0);
      final swapped = pets.activate(1);
      expect(swapped.bonusOf(PetBonus.attack), greaterThan(0));
      expect(swapped.bonusOf(PetBonus.gold), 0);
    });

    test('펫이 없으면 능력치가 그대로다', () {
      final stats = Stats.fromLevels(const {}, config);
      expect(stats.withPet(PetState.empty), same(stats));
    });

    test('치명타는 100%를 넘지 않는다', () {
      final maxed = Stats.fromLevels(const {UpgradeType.critChance: 1000}, config);
      const pet = Pet(grade: PetGrade.legendary, bonus: PetBonus.crit);
      expect(maxed.withPet(PetState.empty.add(pet)).critChance, lessThanOrEqualTo(1.0));
    });

    test('등급이 높을수록 세다', () {
      const low = Pet(grade: PetGrade.common, bonus: PetBonus.attack);
      const high = Pet(grade: PetGrade.legendary, bonus: PetBonus.attack);
      expect(high.value, greaterThan(low.value));
    });
  });

  test('부화·탐험·펫은 저장을 넘어 살아남는다', () {
    var s = engine.startHatch(rich(), 1, EggKind.medium)!;
    s = engine.sendExpedition(s, 2)!;
    s = s.copyWith(pets: PetState.empty.add(const Pet(grade: PetGrade.epic, bonus: PetBonus.gold)));
    final back = decodeState(encodeState(s))!;
    expect(back.hatchery.eggAt(1)?.kind, EggKind.medium);
    expect(back.hatchery.expeditionAt(2)?.stage, s.highestStage);
    expect(back.pets.owned, s.pets.owned);
    expect(back.pets.activeIndex, 0);
  });

  test('부화 이전 저장도 읽힌다', () {
    final j = encodeState(GameState.initial(config))
      ..remove('hatchery')
      ..remove('pets');
    final back = decodeState(j)!;
    expect(back.hatchery.freeEggSlots, HatcheryState.slots);
    expect(back.pets.owned, isEmpty);
  });
}
