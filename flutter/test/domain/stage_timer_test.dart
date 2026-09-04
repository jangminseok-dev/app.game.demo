import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/dungeon.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/quest.dart';
import 'package:idle_fantasy/domain/monster_unit.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);
  final rng = Random(3);

  GameState run(GameState s, double seconds, {double dt = 0.5}) {
    for (var i = 0; i < seconds ~/ dt; i++) {
      s = engine.tick(s, dt, rng);
    }
    return s;
  }

  /// 절대 안 죽는 몬스터가 붙어 있는 상태 — 시간만 흐른다.
  GameState stuck({int kills = 8}) {
    final s = GameState.initial(config).copyWith(killsOnStage: kills, stage: 5);
    return s.copyWith(
      wave: [MonsterUnit(key: 0, id: 1, hp: 1e30, maxHp: 1e30, x: s.heroX + 200, y: s.heroY)],
    );
  }

  group('층 제한 시간', () {
    test('시간이 흐르면 남은 시간이 줄어든다', () {
      final s = run(GameState.initial(config), 5);
      expect(s.stageTimeLeftOr(config), lessThan(config.stageTimeLimit));
      expect(s.stageTimeRatio(config), lessThan(1.0));
    });

    test('시간을 넘기면 진행이 절반 밀리고 시간이 새로 찬다', () {
      var s = stuck(kills: 8);
      s = run(s, config.stageTimeLimit + 1);
      expect(s.stageFailCount, 1, reason: '한 번 밀렸다');
      expect(s.killsOnStage, 4, reason: '절반만 남는다');
      expect(s.stageTimeLeftOr(config), greaterThan(config.stageTimeLimit - 5));
      expect(s.stage, 5, reason: '층은 그대로다');
    });

    test('전부 잃지는 않는다 — 무한 층이라 영영 막히면 안 된다', () {
      expect(config.stageFailKillPenalty, lessThan(1.0));
      var s = stuck(kills: 10);
      s = run(s, config.stageTimeLimit + 1);
      expect(s.stageFailCount, 1);
      expect(s.killsOnStage, greaterThan(0), reason: '밀려도 진행이 남는다');
      expect(s.killsOnStage, lessThan(10), reason: '그래도 잃기는 한다');
    });

    test('새 층으로 넘어가면 시간이 새로 찬다', () {
      var s = GameState.initial(config);
      var guard = 0;
      while (s.stage == 1 && guard++ < 4000) {
        s = engine.tick(s, 0.1, rng);
      }
      expect(s.stage, 2);
      expect(s.stageTimeLeftOr(config), greaterThan(config.stageTimeLimit - 2));
    });

    test('보스전에는 층 시간이 흐르지 않는다 — 보스 시간이 따로 있다', () {
      var s = GameState.initial(config).copyWith(killsOnStage: 0);
      var guard = 0;
      while (!s.isBoss && guard++ < 4000) {
        s = engine.tick(s, 0.1, rng);
      }
      expect(s.isBoss, isTrue);
      final left = s.stageTimeLeftOr(config);
      s = engine.tick(s, 1.0, rng);
      expect(s.stageTimeLeftOr(config), left, reason: '보스 동안에는 멈춘다');
      expect(s.bossTimeLeft, lessThan(config.bossTimeLimit));
    });

    test('던전 안에서는 층 시간이 흐르지 않는다', () {
      var s = engine.enterDungeon(
        GameState.initial(config).copyWith(
          highestStage: 100,
          dungeon: const DungeonState(tickets: 2),
          quests: const QuestState(claimed: 20),
        ),
        DungeonType.goldCave,
        rng,
      )!;
      final left = s.stageTimeLeftOr(config);
      s = engine.tick(s, 1.0, rng);
      expect(s.stageTimeLeftOr(config), left);
    });
  });

  test('남은 시간과 밀린 횟수는 저장된다', () {
    final s = GameState.initial(config).copyWith(stageTimeLeft: 42, stageFailCount: 3);
    final back = decodeState(encodeState(s))!;
    expect(back.stageTimeLeft, 42);
    expect(back.stageFailCount, 3);
  });

  test('제한 시간 이전 저장은 가득 찬 것으로 읽는다', () {
    final j = encodeState(GameState.initial(config))..remove('stageTimeLeft');
    final back = decodeState(j)!;
    expect(back.stageTimeLeftOr(config), config.stageTimeLimit);
  });
}
