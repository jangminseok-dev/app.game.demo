import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/dungeon.dart';
import 'package:idle_fantasy/domain/field.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/monster_unit.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);
  final rng = Random(1);

  /// 던전에 들어갈 수 있는 상태 — 최고 층이 높고 입장권이 있다.
  GameState ready({int highestStage = 100, int tickets = 3}) =>
      GameState.initial(config).copyWith(
        highestStage: highestStage,
        dungeon: DungeonState(tickets: tickets),
      );

  group('입장권', () {
    test('시간이 차면 한 장씩 늘고 상한에서 멈춘다', () {
      var d = const DungeonState(tickets: 0);
      d = d.regenerate(config.dungeonTicketSeconds - 1, config);
      expect(d.tickets, 0, reason: '아직 덜 찼다');
      d = d.regenerate(1, config);
      expect(d.tickets, 1);
      d = d.regenerate(config.dungeonTicketSeconds * 100, config);
      expect(d.tickets, config.dungeonTicketCap, reason: '상한을 넘지 않는다');
    });

    test('여러 장이 한 번에 쌓인다 — 며칠 못 들어와도 손해가 없다', () {
      final d = const DungeonState(tickets: 0).regenerate(config.dungeonTicketSeconds * 3, config);
      expect(d.tickets, 3);
    });

    test('입장하면 한 장이 줄고 진행 중인 판이 생긴다', () {
      final s = engine.enterDungeon(ready(tickets: 2), DungeonType.goldCave, rng)!;
      expect(s.dungeon.tickets, 1);
      expect(s.dungeon.run?.type, DungeonType.goldCave);
      expect(s.dungeon.run?.wavesLeft, config.dungeonWaves);
    });

    test('입장권이 없으면 못 들어간다', () {
      expect(engine.enterDungeon(ready(tickets: 0), DungeonType.goldCave, rng), isNull);
    });

    test('최고 층이 모자라면 잠겨 있다', () {
      expect(engine.enterDungeon(ready(highestStage: 1), DungeonType.goldCave, rng), isNull);
      expect(engine.enterDungeon(ready(highestStage: 15), DungeonType.stoneMine, rng), isNull,
          reason: '강화석 광산은 20층부터');
    });

    test('던전 층은 본편 진행보다 앞서 나갈 수 없다', () {
      // 3층은 환산 15층이라 본편 15층을 찍어야 들어갈 수 있다.
      final s = ready(highestStage: 12).copyWith(
        dungeon: const DungeonState(tickets: 3, cleared: {DungeonType.goldCave: 2}),
      );
      expect(s.dungeon.requiredStage(DungeonType.goldCave, config), 15);
      expect(engine.enterDungeon(s, DungeonType.goldCave, rng), isNull);
      expect(engine.enterDungeon(s.copyWith(highestStage: 15), DungeonType.goldCave, rng), isNotNull);
    });

    test('이미 들어가 있으면 또 못 들어간다', () {
      final s = engine.enterDungeon(ready(), DungeonType.goldCave, rng)!;
      expect(engine.enterDungeon(s, DungeonType.stoneMine, rng), isNull);
    });
  });

  group('한 판', () {
    /// 강한 캐릭터로 던전을 끝까지 민다.
    GameState run(GameState s, {double seconds = 60}) {
      for (var i = 0; i < seconds * 10; i++) {
        s = engine.tick(s, 0.1, rng);
        if (s.dungeon.run == null) break;
      }
      return s;
    }

    test('정해진 수만큼 잡으면 클리어하고 층이 오른다', () {
      var s = engine.enterDungeon(ready(), DungeonType.goldCave, rng)!;
      final before = s.gold;
      s = run(s);
      expect(s.dungeon.run, isNull, reason: '판이 끝났다');
      expect(s.dungeon.clearedFloor(DungeonType.goldCave), 1);
      expect(s.gold, greaterThan(before), reason: '황금 동굴은 골드를 준다');
    });

    test('클리어하면 다음에는 그 다음 층에 도전한다', () {
      var s = engine.enterDungeon(ready(), DungeonType.goldCave, rng)!;
      s = run(s);
      expect(s.dungeon.nextFloor(DungeonType.goldCave), 2);
      s = engine.enterDungeon(s, DungeonType.goldCave, rng)!;
      expect(s.dungeon.run?.floor, 2);
    });

    test('시간이 다 되면 실패하고 층은 그대로다', () {
      var s = engine.enterDungeon(ready(), DungeonType.goldCave, rng)!;
      // 몬스터가 안 죽을 만큼 체력을 키운다.
      s = s.copyWith(wave: [const MonsterUnit(key: 0, id: 1, hp: 1e18, maxHp: 1e18, x: heroHomeX + 20, y: heroHomeY)]);
      s = run(s, seconds: config.dungeonTimeLimit + 5);
      expect(s.dungeon.run, isNull);
      expect(s.dungeon.clearedFloor(DungeonType.goldCave), 0, reason: '실패는 보상이 없다');
      expect(s.dungeon.tickets, 2, reason: '입장권은 돌려주지 않는다');
    });

    test('던전에서 나오면 필드 몬스터로 돌아온다', () {
      var s = engine.enterDungeon(ready(), DungeonType.goldCave, rng)!;
      s = engine.leaveDungeon(s, cleared: false, rng: rng);
      expect(s.dungeon.run, isNull);
      expect(s.monsterHp, s.monsterMaxHp, reason: '새 필드 몬스터가 나온다');
      expect(s.isBoss, isFalse);
    });

    test('던전 처치는 도감 처치 기록에 들어가지 않는다', () {
      var s = engine.enterDungeon(ready(), DungeonType.goldCave, rng)!;
      s = run(s);
      expect(s.killLog, isEmpty, reason: '포획은 필드에서만');
    });
  });

  group('재화', () {
    test('던전 4종은 서로 다른 재화를 준다', () {
      final currencies = {for (final t in DungeonType.values) t.currency};
      expect(currencies.length, DungeonType.values.length);
    });

    test('재화마다 쓰는 곳이 정해져 있다', () {
      for (final c in DungeonCurrency.values) {
        expect(c.sink, isNotEmpty);
      }
    });

    test('강화석 광산은 강화석을, 용의 둥지는 알 조각을 준다', () {
      var s = engine.enterDungeon(ready(), DungeonType.stoneMine, rng)!;
      for (var i = 0; i < 600 && s.dungeon.run != null; i++) {
        s = engine.tick(s, 0.1, rng);
      }
      expect(s.equipment.stones, greaterThan(0));

      var t = engine.enterDungeon(ready(), DungeonType.dragonNest, rng)!;
      for (var i = 0; i < 600 && t.dungeon.run != null; i++) {
        t = engine.tick(t, 0.1, rng);
      }
      expect(t.dungeon.eggShards, greaterThan(0));
    });

    test('깊은 층일수록 보상이 크다', () {
      expect(dungeonReward(DungeonType.goldCave, 5, config),
          greaterThan(dungeonReward(DungeonType.goldCave, 1, config)));
      expect(dungeonReward(DungeonType.dragonNest, 5, config),
          greaterThan(dungeonReward(DungeonType.dragonNest, 1, config)));
    });

    test('깊은 층일수록 몬스터가 세다', () {
      expect(dungeonMonsterHp(5, config), greaterThan(dungeonMonsterHp(1, config)));
    });
  });

  group('저장', () {
    test('진행 중인 판까지 JSON 왕복으로 살아남는다', () {
      final s = engine.enterDungeon(ready(), DungeonType.goldCave, rng)!;
      final back = decodeState(encodeState(s))!;
      expect(back.dungeon.run?.type, s.dungeon.run?.type);
      expect(back.dungeon.run?.wavesLeft, s.dungeon.run?.wavesLeft);
      expect(back.dungeon.tickets, s.dungeon.tickets);
    });

    test('던전 이전 저장도 읽힌다', () {
      final j = encodeState(GameState.initial(config))..remove('dungeon');
      final back = decodeState(j)!;
      expect(back.dungeon.run, isNull);
      expect(back.dungeon.tickets, 3, reason: '기본 입장권');
    });
  });
}
