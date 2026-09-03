import 'dart:math';

import 'balance_config.dart';
import 'formulas.dart';
import 'game_state.dart';

/// 오프라인 보상. GAME_DESIGN.md 8장.
///
/// 경과 시간 동안 저장된 DPS로 현재 스테이지 몬스터를 몇 마리 잡았을지 계산해
/// 그만큼의 골드를 효율(50%)만큼 준다. 스테이지는 올리지 않는다.
class OfflineReward {
  const OfflineReward({required this.elapsed, required this.gold});

  /// 상한이 적용된 경과 시간.
  final Duration elapsed;
  final double gold;

  static const none = OfflineReward(elapsed: Duration.zero, gold: 0);

  static OfflineReward calculate(
    GameState s,
    DateTime savedAt,
    DateTime now,
    BalanceConfig c,
  ) {
    final rawSeconds = now.difference(savedAt).inSeconds.toDouble();
    // 저장 시각이 미래면 시계 조작 — 무효. (서버 시간으로 옮기면 사라지는 검사)
    if (rawSeconds < c.offlineMinSeconds) return none;

    final seconds = min(rawSeconds, c.offlineCapSeconds);
    final stats = s.statsWith(c);
    final kills = stats.dps(c) * seconds / monsterHp(s.stage, c);
    final gold = kills *
        goldReward(s.stage, c) *
        stats.goldMultiplier *
        c.offlineEfficiency;
    return OfflineReward(
      elapsed: Duration(seconds: seconds.round()),
      gold: gold,
    );
  }
}
