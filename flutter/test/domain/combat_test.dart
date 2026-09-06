import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/dungeon.dart';
import 'package:idle_fantasy/domain/field.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/quest.dart';
import 'package:idle_fantasy/domain/monster_unit.dart';
import 'package:idle_fantasy/domain/save_codec.dart';
import 'package:idle_fantasy/domain/skill.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);
  final rng = Random(11);

  GameState run(GameState s, double seconds, {double dt = 1 / 30}) {
    for (var i = 0; i < seconds ~/ dt; i++) {
      s = engine.tick(s, dt, rng);
    }
    return s;
  }

  double heroDistanceTo(GameState s, MonsterUnit m) =>
      distanceBetween(s.heroX, s.heroY, m.x, m.y);

  group('이동', () {
    test('몬스터는 화면 밖에서 시작해 주인공 쪽으로 온다', () {
      final start = GameState.initial(config);
      for (final m in start.wave) {
        expect(m.x, greaterThanOrEqualTo(spawnAheadOfHero));
      }
      final later = run(start, 0.5);
      for (final m in later.wave) {
        expect(m.x, lessThan(spawnAheadOfHero), reason: '전부 앞으로 나왔다');
      }
    });

    test('무리는 한꺼번에 움직인다 — 한 마리씩 오지 않는다', () {
      var s = GameState.initial(config);
      final before = [for (final m in s.wave) m.x];
      s = engine.tick(s, 0.1, rng);
      final after = [for (final m in s.wave) m.x];
      for (var i = 0; i < before.length; i++) {
        expect(after[i], lessThan(before[i]), reason: '${i + 1}번째도 같은 틱에 움직였다');
      }
    });

    test('주인공은 가장 가까운 몬스터 쪽으로 간다', () {
      final far = MonsterUnit(key: 1, id: 1, hp: 100, maxHp: 100, x: 340, y: fieldTopY);
      final near = MonsterUnit(key: 2, id: 1, hp: 100, maxHp: 100, x: 200, y: fieldBottomY);
      var s = GameState.initial(config).copyWith(wave: [far, near]);
      expect(s.nearestMonster?.key, 2);
      s = engine.tick(s, 0.1, rng);
      // 가까운 쪽(아래)으로 내려갔다.
      expect(s.heroY, greaterThan(heroHomeY));
    });

    test('사거리에 닿으면 멈춘다 — 겹쳐 서지 않는다', () {
      var s = run(GameState.initial(config), 6);
      for (final m in s.wave) {
        expect(heroDistanceTo(s, m), greaterThan(4), reason: '주인공 위에 올라타지 않는다');
      }
    });

    test('몬스터끼리 겹치지 않게 서로 밀어낸다', () {
      final stacked = [
        for (var i = 0; i < 4; i++)
          MonsterUnit(key: i, id: 1, hp: 1e9, maxHp: 1e9, x: 120, y: heroHomeY),
      ];
      var s = GameState.initial(config).copyWith(wave: stacked);
      s = run(s, 1);
      for (var i = 0; i < s.wave.length; i++) {
        for (var j = i + 1; j < s.wave.length; j++) {
          final d = distanceBetween(s.wave[i].x, s.wave[i].y, s.wave[j].x, s.wave[j].y);
          expect(d, greaterThan(1), reason: '완전히 겹치지는 않는다');
        }
      }
    });

    test('아무도 없으면 제자리에 선다 — 돌아갈 집이 없다', () {
      var s = GameState.initial(config).copyWith(wave: const [], heroX: 300, heroY: fieldTopY);
      s = engine.tick(s, 0.1, rng);
      expect(s.heroX, 300, reason: '가로가 끝이 없어 돌아갈 집이 없다');
    });
  });

  group('서로 때린다', () {
    /// 몬스터를 주인공 옆에 붙여 둔 상태.
    GameState engaged({int count = 3, double hp = 1e9}) {
      final s = GameState.initial(config);
      return s.copyWith(
        wave: [
          for (var i = 0; i < count; i++)
            MonsterUnit(key: i, id: 1, hp: hp, maxHp: hp, x: s.heroX + 16, y: s.heroY),
        ],
      );
    }

    test('붙은 몬스터는 주인공의 체력을 깎는다', () {
      var s = engaged();
      final full = s.maxHeroHp(config);
      s = run(s, 4);
      expect(s.heroHpOr(config), lessThan(full));
    });

    test('멀리 있으면 서로 못 때린다', () {
      var s = GameState.initial(config);
      final full = s.maxHeroHp(config);
      final monsterHp = s.wave.first.hp;
      s = engine.tick(s, 0.1, rng);
      expect(s.heroHpOr(config), full, reason: '아직 안 닿았다');
      expect(s.wave.first.hp, monsterHp);
    });

    test('보스는 더 아프다', () {
      var normal = engaged(count: 1);
      var boss = engaged(count: 1).copyWith(isBoss: true);
      normal = run(normal, 4);
      boss = run(boss, 4);
      expect(boss.heroHpOr(config), lessThan(normal.heroHpOr(config)));
    });

    test('체력과 마력은 시간이 지나면 찬다', () {
      final s = GameState.initial(config);
      final hurt = s.copyWith(heroHp: 10, heroMp: 0);
      final healed = run(hurt, 2);
      expect(healed.heroHpOr(config), greaterThan(10));
      expect(healed.heroMpOr(config), greaterThan(0));
    });

    test('회복은 최대치를 넘지 않는다', () {
      final s = run(GameState.initial(config), 30);
      expect(s.heroHpOr(config), lessThanOrEqualTo(s.maxHeroHp(config)));
      expect(s.heroMpOr(config), lessThanOrEqualTo(s.maxHeroMp(config)));
    });

    test('업그레이드를 올리면 몸과 마력도 커진다', () {
      final weak = GameState.initial(config);
      final strong = weak.copyWith(levels: const {UpgradeType.attack: 10, UpgradeType.critChance: 5});
      expect(strong.totalUpgradeLevels, 15);
      expect(strong.maxHeroHp(config), greaterThan(weak.maxHeroHp(config)));
      expect(strong.maxHeroMp(config), greaterThan(weak.maxHeroMp(config)));
    });
  });

  group('쓰러짐', () {
    /// 아주 아픈 몬스터가 붙어 있는 상태.
    GameState doomed() {
      final s = GameState.initial(config).copyWith(stage: 400, killsOnStage: 5);
      return s.copyWith(
        heroHp: 1,
        wave: [MonsterUnit(key: 0, id: 1, hp: 1e30, maxHp: 1e30, x: s.heroX + 10, y: s.heroY)],
      );
    }

    test('체력이 다하면 쓰러지고 같은 층 처음부터 다시 한다', () {
      // 몬스터는 붙자마자가 아니라 공격 주기(약 1.7초)마다 때린다.
      final before = doomed().heroX;
      final down = run(doomed(), 2);
      expect(down.isDown, isTrue);
      expect(down.killsOnStage, 0, reason: '층 진행이 초기화된다');
      expect(down.heroX, before, reason: '가로 자리는 그대로다');
      expect(down.isBoss, isFalse);
    });

    test('쓰러져 있는 동안에는 때리지도 맞지도 않는다', () {
      var s = run(doomed(), 2);
      expect(s.isDown, isTrue);
      final kills = s.totalKills;
      s = engine.tick(s, 0.1, rng);
      expect(s.totalKills, kills);
      expect(s.heroHpOr(config), 0, reason: '일어서기 전에는 회복도 없다');
    });

    test('정해진 시간이 지나면 가득 찬 체력으로 일어선다', () {
      var s = run(doomed(), 2);
      s = run(s, config.heroReviveSeconds + 0.5);
      expect(s.isDown, isFalse);
      expect(s.heroHpOr(config), greaterThan(0));
    });

    test('던전에서 쓰러지면 그 판은 실패다', () {
      var s = engine.enterDungeon(
        GameState.initial(config)
            .copyWith(highestStage: 100, dungeon: const DungeonState(tickets: 2), quests: const QuestState(claimed: 20)),
        DungeonType.goldCave,
        rng,
      )!;
      expect(s.dungeon.run, isNotNull);
      s = s.copyWith(
        heroHp: 1,
        stage: 400,
        wave: [MonsterUnit(key: 0, id: 1, hp: 1e30, maxHp: 1e30, x: s.heroX + 10, y: s.heroY)],
      );
      s = run(s, 2);
      expect(s.isDown, isTrue);
      expect(s.dungeon.run, isNull, reason: '던전에서 쫓겨난다');
      expect(s.dungeon.clearedFloor(DungeonType.goldCave), 0);
    });
  });

  group('마력', () {
    GameState armed() {
      var s = GameState.initial(config).copyWith(
        highestStage: 300,
        dungeon: const DungeonState(skillPages: 5000),
      );
      s = engine.unlockSkill(s, SkillId.meteor)!;
      return s.copyWith(
        wave: [
          for (var i = 0; i < 3; i++)
            MonsterUnit(key: i, id: 1, hp: 1e9, maxHp: 1e9, x: s.heroX + 16, y: s.heroY),
        ],
      );
    }

    test('스킬을 쓰면 마력이 준다', () {
      var s = armed();
      final before = s.heroMpOr(config);
      s = engine.tick(s, 0.05, rng);
      expect(s.heroMpOr(config), lessThan(before));
    });

    test('마력이 모자라면 자동으로도 안 나간다', () {
      var s = armed().copyWith(heroMp: 0);
      s = engine.tick(s, 0.01, rng);
      expect(s.skills.cooldownAt(0), 0, reason: '대기 시간이 돌지 않았다 = 안 나갔다');
    });

    test('마력이 모자라면 탭해도 안 나간다', () {
      final s = armed().copyWith(heroMp: 0);
      expect(engine.canCast(s, 0), isFalse);
      expect(engine.useSkill(s, 0, rng), isNull);
    });

    test('쓰러져 있으면 탭해도 안 나간다', () {
      final s = armed().copyWith(reviveLeft: 2);
      expect(engine.canCast(s, 0), isFalse);
    });
  });

  test('주인공 상태는 저장을 넘어 살아남는다', () {
    final s = GameState.initial(config).copyWith(heroHp: 42, heroMp: 7);
    final back = decodeState(encodeState(s))!;
    expect(back.heroHp, 42);
    expect(back.heroMp, 7);
    expect(back.wave.first.x, s.wave.first.x, reason: '몬스터 자리도 남는다');
  });

  test('주인공 상태가 없던 저장은 가득 찬 것으로 읽는다', () {
    final j = encodeState(GameState.initial(config))
      ..remove('heroHp')
      ..remove('heroMp');
    final back = decodeState(j)!;
    expect(back.heroHpOr(config), back.maxHeroHp(config));
    expect(back.heroMpOr(config), back.maxHeroMp(config));
  });

  test('몬스터 띠가 무대 안에 있다 — 가로 전환 때 밖으로 나간 적이 있다', () {
    expect(fieldTopY, greaterThanOrEqualTo(0));
    expect(fieldBottomY, lessThanOrEqualTo(fieldHeight));
    expect(heroHomeY, inInclusiveRange(fieldTopY, fieldBottomY));
  });
}
