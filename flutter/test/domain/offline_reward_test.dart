import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/formulas.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/offline_reward.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

void main() {
  const c = BalanceConfig();
  final base = DateTime(2026, 9, 3, 12);

  test('경과 시간 × DPS만큼 잡은 몬스터의 골드를 50%로 준다', () {
    final s = GameState.initial(c).copyWith(
      stage: 5,
      levels: const {UpgradeType.goldGain: 4}, // ×1.2
    );
    final r = OfflineReward.calculate(s, base, base.add(const Duration(hours: 1)), c);

    final kills = s.stats.dps(c) * 3600 / monsterHp(5, c);
    final expected = kills * goldReward(5, c) * 1.2 * 0.5;
    expect(r.gold, closeTo(expected, 1e-6));
    expect(r.elapsed, const Duration(hours: 1));
  });

  test('8시간 상한', () {
    final s = GameState.initial(c);
    final r8 = OfflineReward.calculate(s, base, base.add(const Duration(hours: 8)), c);
    final r30 = OfflineReward.calculate(s, base, base.add(const Duration(hours: 30)), c);
    expect(r30.gold, r8.gold);
    expect(r30.elapsed, const Duration(hours: 8));
  });

  test('1분 미만은 보상 없음', () {
    final s = GameState.initial(c);
    final r = OfflineReward.calculate(s, base, base.add(const Duration(seconds: 59)), c);
    expect(r.gold, 0);
  });

  test('저장 시각이 미래면(시계 조작) 보상 없음', () {
    final s = GameState.initial(c);
    final r = OfflineReward.calculate(s, base.add(const Duration(hours: 5)), base, c);
    expect(r.gold, 0);
    expect(r.elapsed, Duration.zero);
  });

  test('보상은 골드만, 스테이지는 그대로', () {
    final s = GameState.initial(c).copyWith(stage: 3);
    final r = OfflineReward.calculate(s, base, base.add(const Duration(hours: 2)), c);
    expect(r.gold, greaterThan(0));
    // calculate는 상태를 바꾸지 않는다 — 스테이지 반영은 호출 측(Bootstrap) 몫이며 골드만 더한다.
  });
}
