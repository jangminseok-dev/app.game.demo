import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/codex.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

import '../support/catalog.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);

  // 치명타를 0으로 고정하려고 항상 1.0 근처를 돌려주는 난수.
  final noCrit = _FixedRandom(0.999);

  GameState run(GameState s, double seconds, {double dt = 0.1, Random? rng}) {
    final r = rng ?? noCrit;
    var t = 0.0;
    while (t < seconds) {
      s = engine.tick(s, dt, r);
      t += dt;
    }
    return s;
  }

  /// 조건이 참이 될 때까지 진행. maxSeconds 안에 못 만나면 실패.
  GameState runUntil(GameState s, bool Function(GameState) done,
      {double maxSeconds = 120}) {
    var t = 0.0;
    while (!done(s)) {
      if (t >= maxSeconds) fail('$maxSeconds초 안에 조건 미도달');
      s = engine.tick(s, 0.1, noCrit);
      t += 0.1;
    }
    return s;
  }

  group('전투 흐름', () {
    test('초기 상태: 1스테이지, 일반 몬스터, 골드 0', () {
      final s = GameState.initial(config);
      expect(s.stage, 1);
      expect(s.isBoss, false);
      expect(s.gold, 0);
      expect(s.monsterHp, s.monsterMaxHp);
    });

    test('공격속도 1.0이면 1초에 1회 때린다', () {
      var s = GameState.initial(config);
      s = engine.tick(s, 0.5, noCrit);
      expect(s.monsterHp, s.monsterMaxHp, reason: '0.5초에는 안 때린다');
      s = engine.tick(s, 0.5, noCrit);
      expect(s.monsterHp, lessThan(s.monsterMaxHp));
    });

    test('몬스터를 죽이면 골드가 오르고 처치 수가 는다', () {
      var s = GameState.initial(config);
      s = run(s, 3); // 공격 10 × 2회 > HP 11.8
      expect(s.totalKills, greaterThanOrEqualTo(1));
      expect(s.gold, greaterThan(0));
    });

    test('일반 10마리를 잡으면 보스가 나온다', () {
      var s = GameState.initial(config);
      s = runUntil(s, (s) => s.isBoss);
      expect(s.totalKills, config.killsPerStage);
      expect(s.killsOnStage, config.killsPerStage);
      expect(s.stage, 1);
      expect(s.bossTimeLeft, config.bossTimeLimit);
      expect(s.monsterMaxHp, closeTo(11.8 * 10, 1e-9));
    });

    test('보스를 잡으면 다음 스테이지로 간다', () {
      var s = GameState.initial(config);
      s = runUntil(s, (s) => s.isBoss);
      s = runUntil(s, (s) => s.stage == 2);
      expect(s.highestStage, 2);
      expect(s.isBoss, false);
      expect(s.killsOnStage, 0);
      expect(s.totalKills, config.killsPerStage + 1);
    });

    test('보스 30초 안에 못 잡으면 같은 스테이지 일반 몬스터부터 다시', () {
      const weak = BalanceConfig(bossHpMultiplier: 100000);
      const e = BattleEngine(weak);
      var s = GameState.initial(weak);
      var t = 0.0;
      while (!s.isBoss && t < 60) {
        s = e.tick(s, 0.1, noCrit);
        t += 0.1;
      }
      expect(s.isBoss, true);
      for (var i = 0; i < 310; i++) {
        s = e.tick(s, 0.1, noCrit);
      }
      expect(s.isBoss, false);
      expect(s.stage, 1);
      expect(s.killsOnStage, 0);
    });

    test('치명타는 피해 2배', () {
      var s = GameState.initial(config).copyWith(monsterHp: 100, monsterMaxHp: 100);
      final alwaysCrit = _FixedRandom(0.0);
      s = engine.tick(s, 1.0, alwaysCrit);
      expect(s.monsterMaxHp - s.monsterHp, closeTo(20, 1e-9));
    });
  });

  group('업그레이드', () {
    test('골드가 모자라면 null', () {
      final s = GameState.initial(config);
      expect(engine.buyUpgrade(s, UpgradeType.attack), isNull);
    });

    test('사면 골드가 줄고 레벨이 오르고 다음 비용이 오른다', () {
      var s = GameState.initial(config).copyWith(gold: 100);
      s = engine.buyUpgrade(s, UpgradeType.attack)!;
      expect(s.gold, 90);
      expect(s.levelOf(UpgradeType.attack), 1);
      expect(s.stats.attack, 15);
      expect(UpgradeType.attack.cost(1, config), greaterThan(10));
    });

    test('골드획득 업그레이드는 보상에 곱해진다', () {
      var s = GameState.initial(config).copyWith(
        levels: const {UpgradeType.goldGain: 10}, // ×1.5
      );
      s = run(s, 2.5); // 1마리
      final base = config.goldBase * pow(config.goldGrowth, 1);
      expect(s.gold, closeTo(base * 1.5, 1e-9));
    });
  });

  group('도감 연동 (6주차)', () {
    const withCatalog = BattleEngine(config, catalog: smallCatalog);

    test('스폰 시 스테이지의 몬스터 id가 붙고 처치가 몬스터별로 기록된다', () {
      var s = GameState.initial(config);
      // 1스테이지 = 슬라임(1). 보스 전까지 10마리 → killLog[1] == 10, 보스 처치 → bossKillLog[1] == 1
      var t = 0.0;
      while (s.stage == 1 && t < 200) {
        s = withCatalog.tick(s, 0.1, noCrit);
        t += 0.1;
      }
      expect(s.stage, 2);
      expect(s.killLog, {1: 10});
      expect(s.bossKillLog, {1: 1});
      expect(s.monsterId, 2, reason: '2스테이지 = 늑대');
    });

    test('카탈로그가 없으면 monsterId는 그대로', () {
      var s = GameState.initial(config);
      s = engine.tick(s, 3, noCrit);
      expect(s.monsterId, 1);
      expect(s.killLog, {1: 1});
    });

    test('보낸 보고만 빼고 그 사이 쌓인 처치는 남는다', () {
      final s = GameState.initial(config).copyWith(killLog: const {1: 7, 2: 1}, bossKillLog: const {1: 1});
      final left = withCatalog.consumeKillLog(s, const {1: 5}, const {1: 1});
      expect(left.killLog, {1: 2, 2: 1});
      expect(left.bossKillLog, isEmpty);
    });

    test('포획 이벤트를 도감에 반영하면 패시브가 따라온다', () {
      var s = GameState.initial(config);
      s = withCatalog.applyCaptures(s, const [
        CaptureEvent(monsterId: 1, stars: 1, first: true),
        CaptureEvent(monsterId: 1, stars: 2, first: false),
        CaptureEvent(monsterId: 2, stars: 1, first: true),
      ]);
      expect(s.codex, {1: 2, 2: 1});
      expect(s.passives.gold, closeTo(1.0, 1e-9));
      expect(s.passives.attack, 20, reason: '숲 완성 보너스');
      expect(s.stats.attack, 12);
    });

    test('빈 이벤트는 상태를 바꾸지 않는다', () {
      final s = GameState.initial(config);
      expect(identical(withCatalog.applyCaptures(s, const []), s), true);
    });
  });
}

/// nextDouble이 항상 같은 값을 돌려주는 난수. 치명타 판정을 고정할 때 쓴다.
class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;

  @override
  double nextDouble() => value;
  @override
  bool nextBool() => value < 0.5;
  @override
  int nextInt(int max) => (value * max).floor();
}
