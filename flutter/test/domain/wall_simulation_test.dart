import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

/// GAME_DESIGN.md 4장 "가장 중요한 원칙" 검증.
///
/// 보상 성장률(1.15) < 요구치 성장률(1.18)이면 골드를 최대한 효율적으로
/// 써도 스테이지 하나를 넘는 데 걸리는 시간이 점점 길어져야 한다(= 벽).
/// 정책: 1초마다 살 수 있는 것 중 가장 싼 업그레이드를 산다(포획률 제외).
void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);

  test('스테이지 클리어 시간이 뒤로 갈수록 길어진다 (벽이 생긴다)', () {
    var s = GameState.initial(config);
    final rng = Random(42);
    const dt = 0.1;
    const maxSeconds = 6 * 3600.0; // 6시간 게임 시간
    const targets = [10, 20, 30, 40];
    final reached = <int, double>{};

    var t = 0.0;
    var lastBuyAt = 0.0;
    while (t < maxSeconds && reached.length < targets.length) {
      s = engine.tick(s, dt, rng);
      t += dt;

      if (t - lastBuyAt >= 1.0) {
        lastBuyAt = t;
        s = _buyCheapest(engine, s);
      }

      for (final target in targets) {
        if (!reached.containsKey(target) && s.stage >= target) {
          reached[target] = t;
        }
      }
    }

    // 결과를 눈으로 볼 수 있게 남긴다.
    for (final target in targets) {
      final at = reached[target];
      // ignore: avoid_print
      print('stage $target: ${at == null ? '미도달' : '${(at / 60).toStringAsFixed(1)}분'}');
    }

    expect(reached.keys, containsAll(targets), reason: '6시간 안에 40층은 가야 한다');

    final t10to20 = reached[20]! - reached[10]!;
    final t20to30 = reached[30]! - reached[20]!;
    final t30to40 = reached[40]! - reached[30]!;
    expect(t20to30, greaterThan(t10to20));
    expect(t30to40, greaterThan(t20to30));
  });
}

GameState _buyCheapest(BattleEngine engine, GameState s) {
  const candidates = [
    UpgradeType.attack,
    UpgradeType.attackSpeed,
    UpgradeType.critChance,
    UpgradeType.goldGain,
  ];
  while (true) {
    UpgradeType? cheapest;
    var cheapestCost = double.infinity;
    for (final t in candidates) {
      final c = t.cost(s.levelOf(t), engine.config);
      if (c < cheapestCost) {
        cheapestCost = c;
        cheapest = t;
      }
    }
    final next = engine.buyUpgrade(s, cheapest!);
    if (next == null) return s;
    s = next;
  }
}
