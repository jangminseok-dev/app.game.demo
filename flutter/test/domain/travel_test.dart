import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/dungeon.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/quest.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);
  final rng = Random(5);

  GameState at(int stage, {int highest = 50}) =>
      GameState.initial(config).copyWith(stage: stage, highestStage: highest, killsOnStage: 7);

  test('낮은 층으로 내려갈 수 있다', () {
    final s = engine.travelTo(at(30), 10, rng)!;
    expect(s.stage, 10);
    expect(s.highestStage, 50, reason: '최고 층은 그대로다');
    expect(s.killsOnStage, 0, reason: '층 진행은 새로 시작한다');
    expect(s.stageTimeLeftOr(config), config.stageTimeLimit, reason: '시간도 새로 준다');
  });

  test('최고 층 위로는 못 간다 — 최고 층으로 잘린다', () {
    final s = engine.travelTo(at(10), 999, rng)!;
    expect(s.stage, 50);
  });

  test('1층 아래로도 못 간다', () {
    final s = engine.travelTo(at(10), -5, rng)!;
    expect(s.stage, 1);
  });

  test('제자리로는 안 움직인다', () {
    expect(engine.travelTo(at(10), 10, rng), isNull);
  });

  test('보스전 중이어도 내려가면 일반 몬스터부터 다시 한다', () {
    final s = engine.travelTo(at(30).copyWith(isBoss: true, bossTimeLeft: 5), 20, rng)!;
    expect(s.isBoss, isFalse);
    expect(s.bossTimeLeft, 0);
  });

  test('던전 안에서는 못 옮긴다', () {
    final s = engine.enterDungeon(
      GameState.initial(config).copyWith(
        highestStage: 100,
        dungeon: const DungeonState(tickets: 2),
        quests: const QuestState(claimed: 20),
      ),
      DungeonType.goldCave,
      rng,
    )!;
    expect(engine.travelTo(s, 5, rng), isNull);
  });

  test('쓰러져 있으면 못 옮긴다', () {
    expect(engine.travelTo(at(30).copyWith(reviveLeft: 2), 10, rng), isNull);
  });

  test('내려가서 깨면 다시 위로 올라간다', () {
    var s = engine.travelTo(at(30), 2, rng)!;
    var guard = 0;
    while (s.stage == 2 && guard++ < 6000) {
      s = engine.tick(s, 0.1, rng);
    }
    expect(s.stage, 3);
    expect(s.highestStage, 50, reason: '최고 층은 안 내려간다');
  });
}
