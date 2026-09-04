import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/dungeon.dart';
import 'package:idle_fantasy/domain/equipment.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/pet.dart';
import 'package:idle_fantasy/domain/quest.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);
  final initial = GameState.initial(config);

  group('퀘스트 표', () {
    test('60개가 1번부터 번호순으로 있다', () {
      expect(questTable.length, 60);
      for (var i = 0; i < questTable.length; i++) {
        expect(questTable[i].number, i + 1);
      }
    });

    test('앞 20개는 시스템을 하나씩 연다', () {
      final opening = questTable.take(20).map((q) => q.goal).toList();
      // 전투 → 장비 → 강화 → 진행 → 던전 → 도감 → 펫 순으로 처음 나온다.
      int firstOf(QuestGoal g) => opening.indexOf(g);
      expect(firstOf(QuestGoal.totalKills), 0);
      expect(firstOf(QuestGoal.equipWorn), lessThan(firstOf(QuestGoal.enhanceLevel)));
      expect(firstOf(QuestGoal.enhanceLevel), lessThan(firstOf(QuestGoal.dungeonFloors)));
      expect(firstOf(QuestGoal.dungeonFloors), lessThan(firstOf(QuestGoal.petsOwned)));
    });

    test('같은 목표는 뒤로 갈수록 목표치가 커진다', () {
      // 앞 20개는 손으로 적은 튜토리얼이라 뒤 40개만 본다.
      for (final goal in QuestGoal.values) {
        final targets =
            questTable.skip(20).where((q) => q.goal == goal).map((q) => q.target).toList();
        for (var i = 1; i < targets.length; i++) {
          expect(targets[i], greaterThanOrEqualTo(targets[i - 1]), reason: '${goal.label}');
        }
      }
    });

    test('목표 5종과 보상 5종이 모두 쓰인다', () {
      expect(questTable.map((q) => q.goal).toSet(), QuestGoal.values.toSet());
      expect(questTable.map((q) => q.reward).toSet(), RewardKind.values.toSet());
    });

    test('보상은 항상 1 이상이다', () {
      for (final q in questTable) {
        expect(q.rewardAmount, greaterThan(0), reason: '${q.number}번');
      }
    });
  });

  group('진행과 수령', () {
    test('처음에는 1번이 진행 중이고 아직 못 받는다', () {
      expect(initial.quests.current?.number, 1);
      expect(questReady(initial), isFalse);
      expect(engine.claimQuest(initial), isNull);
    });

    test('조건을 채우면 받을 수 있고 다음 번호로 넘어간다', () {
      final first = questTable.first;
      final s = initial.copyWith(totalKills: first.target);
      expect(questReady(s), isTrue);
      final claimed = engine.claimQuest(s)!;
      expect(claimed.quests.current?.number, 2);
    });

    test('보상이 재화별 자리에 들어간다', () {
      // 1번 골드, 2번 골드, 3번 강화석, 7번 입장권.
      var s = _allDone(initial);
      final gold = engine.claimQuest(s)!;
      expect(gold.gold, greaterThan(s.gold));
      s = gold;
      for (var i = 0; i < 2; i++) {
        s = engine.claimQuest(s)!;
      }
      expect(s.equipment.stones, greaterThan(gold.equipment.stones), reason: '3번은 강화석');
    });

    test('입장권 보상도 상한을 넘지 않는다', () {
      var s = _allDone(initial).copyWith(dungeon: DungeonState(tickets: config.dungeonTicketCap));
      // 7번이 입장권이다. 거기까지 받아 본다.
      for (var i = 0; i < 7; i++) {
        s = engine.claimQuest(s)!;
      }
      expect(s.dungeon.tickets, config.dungeonTicketCap);
    });

    test('진행도는 상태에서 계산한다 — 따로 세지 않는다', () {
      final kills = questTable.firstWhere((q) => q.goal == QuestGoal.totalKills);
      expect(questProgress(kills, initial.copyWith(totalKills: 7)), 7);

      final codex = questTable.firstWhere((q) => q.goal == QuestGoal.codexRegistered);
      expect(questProgress(codex, initial.copyWith(codex: {1: 2, 2: 0, 3: 1})), 2);

      final floors = questTable.firstWhere((q) => q.goal == QuestGoal.dungeonFloors);
      final s = initial.copyWith(
        dungeon: const DungeonState(cleared: {DungeonType.goldCave: 3, DungeonType.stoneMine: 2}),
      );
      expect(questProgress(floors, s), 5);
    });

    test('60개를 다 받으면 더 없다', () {
      var s = initial.copyWith(quests: const QuestState(claimed: 60));
      expect(s.quests.current, isNull);
      expect(questReady(s), isFalse);
      expect(engine.claimQuest(s), isNull);
      s = s.copyWith(highestStage: 100000);
      expect(engine.claimQuest(s), isNull);
    });
  });

  group('해금표', () {
    test('아직 안 열린 것 중 가장 가까운 것을 알려 준다', () {
      expect(nextUnlock(1)?.$1, 10);
      expect(nextUnlock(10)?.$1, 20);
      expect(nextUnlock(99)?.$1, 100);
      expect(nextUnlock(100000), isNull);
    });

    test('층은 오름차순이다', () {
      for (var i = 1; i < unlockTable.length; i++) {
        expect(unlockTable[i].$1, greaterThan(unlockTable[i - 1].$1));
      }
    });

    test('던전 해금 층은 던전 정의와 같다', () {
      for (final type in DungeonType.values) {
        final row = unlockTable.where((e) => e.$2 == type.label).firstOrNull;
        expect(row, isNotNull, reason: '${type.label}이 해금표에 있다');
        expect(row!.$1, type.unlockStage);
      }
    });
  });

  test('받은 퀘스트 수는 저장된다', () {
    final s = initial.copyWith(quests: const QuestState(claimed: 7));
    expect(decodeState(encodeState(s))!.quests.claimed, 7);
    final old = encodeState(initial)..remove('quests');
    expect(decodeState(old)!.quests.claimed, 0);
  });
}

/// 앞 20개 퀘스트 조건을 전부 채운 상태.
GameState _allDone(GameState s) => s.copyWith(
      highestStage: 1000,
      totalKills: 100000,
      codex: const {1: 3, 2: 1, 3: 1, 4: 1, 5: 1},
      equipment: const EquipmentState(
        enhanceLevel: 100,
        equipped: {
          EquipSlot.weapon: Equipment(slot: EquipSlot.weapon, grade: EquipGrade.common, tier: 0),
          EquipSlot.helmet: Equipment(slot: EquipSlot.helmet, grade: EquipGrade.common, tier: 0),
          EquipSlot.cape: Equipment(slot: EquipSlot.cape, grade: EquipGrade.common, tier: 0),
          EquipSlot.armor: Equipment(slot: EquipSlot.armor, grade: EquipGrade.common, tier: 0),
          EquipSlot.ring: Equipment(slot: EquipSlot.ring, grade: EquipGrade.common, tier: 0),
          EquipSlot.amulet: Equipment(slot: EquipSlot.amulet, grade: EquipGrade.common, tier: 0),
        },
      ),
      dungeon: const DungeonState(
        cleared: {DungeonType.goldCave: 10, DungeonType.stoneMine: 10},
      ),
      pets: const PetState(owned: [Pet(grade: PetGrade.common, bonus: PetBonus.attack)], activeIndex: 0),
    );
