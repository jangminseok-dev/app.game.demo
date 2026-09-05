import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/daily.dart';
import 'package:idle_fantasy/domain/dungeon.dart';
import 'package:idle_fantasy/domain/equipment.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);
  final initial = GameState.initial(config);

  test('날이 바뀌면 오늘 눈금이 새로 잡힌다', () {
    final s = engine.refreshDaily(initial.copyWith(totalKills: 500), 10);
    expect(s.daily.day, 10);
    expect(s.daily.killsAtStart, 500);
    expect(dailyProgress(DailyGoal.kills, s), 0, reason: '오늘은 아직 0마리');
  });

  test('같은 날에는 눈금을 다시 잡지 않는다', () {
    var s = engine.refreshDaily(initial.copyWith(totalKills: 500), 10);
    s = s.copyWith(totalKills: 600);
    s = engine.refreshDaily(s, 10);
    expect(dailyProgress(DailyGoal.kills, s), 100, reason: '눈금이 그대로여야 오늘 100마리로 읽힌다');
  });

  test('목표를 채우면 받을 수 있고 한 번만 받는다', () {
    var s = engine.refreshDaily(initial, 1);
    expect(dailyReady(DailyGoal.kills, s), isFalse);
    s = s.copyWith(totalKills: DailyGoal.kills.target);
    expect(dailyReady(DailyGoal.kills, s), isTrue);

    final claimed = engine.claimDaily(s, DailyGoal.kills)!.$1;
    // 처치 과제는 골드가 아니라 소환석을 준다 — 접속 보상이 소환 축을 먹인다.
    expect(claimed.summon.stones, greaterThan(s.summon.stones));
    expect(engine.claimDaily(claimed, DailyGoal.kills), isNull, reason: '두 번은 안 된다');
  });

  test('날이 바뀌면 받은 기록도 초기화된다', () {
    var s = engine.refreshDaily(initial, 1).copyWith(totalKills: DailyGoal.kills.target);
    s = engine.claimDaily(s, DailyGoal.kills)!.$1;
    expect(s.daily.isClaimed(DailyGoal.kills), isTrue);
    s = engine.refreshDaily(s, 2);
    expect(s.daily.isClaimed(DailyGoal.kills), isFalse);
  });

  test('던전과 제작도 오늘치로 잰다', () {
    var s = engine.refreshDaily(initial, 1);
    s = s.copyWith(
      dungeon: const DungeonState(cleared: {DungeonType.goldCave: 2}),
      equipment: const EquipmentState(craftLevel: 5),
    );
    expect(dailyProgress(DailyGoal.dungeonFloors, s), 2);
    expect(dailyProgress(DailyGoal.crafts, s), 5);
    expect(anyDailyReady(s), isTrue);
  });

  test('과제 셋은 서로 다른 보상을 준다', () {
    final rewards = {for (final g in DailyGoal.values) g.reward};
    expect(rewards.length, DailyGoal.values.length);
  });

  test('오늘 과제는 저장된다', () {
    var s = engine.refreshDaily(initial, 77).copyWith(totalKills: DailyGoal.kills.target);
    s = engine.claimDaily(s, DailyGoal.kills)!.$1;
    final back = decodeState(encodeState(s))!;
    expect(back.daily.day, 77);
    expect(back.daily.isClaimed(DailyGoal.kills), isTrue);
  });

  test('일일 과제 이전 저장도 읽힌다', () {
    final j = encodeState(initial)..remove('daily');
    expect(decodeState(j)!.daily.day, -1);
  });
}
