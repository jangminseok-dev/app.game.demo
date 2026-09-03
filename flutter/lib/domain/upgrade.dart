import 'dart:math';

import 'balance_config.dart';

/// 골드로 사는 능력치 업그레이드 5종. GAME_DESIGN.md 3장·17장.
///
/// 능력치는 레벨에 선형으로 붙고(4장), 비용만 지수로 오른다.
enum UpgradeType {
  attack('공격력', baseCost: 10),
  attackSpeed('공격속도', baseCost: 25),
  critChance('치명타', baseCost: 50),
  goldGain('골드획득', baseCost: 40),
  // 포획 시스템(6주차)이 들어오기 전까지는 효과가 없다. 정의만 미리 둔다.
  captureRate('포획률', baseCost: 100);

  const UpgradeType(this.label, {required this.baseCost});

  final String label;
  final double baseCost;

  double cost(int level, BalanceConfig config) =>
      baseCost * pow(config.upgradeCostGrowth, level);
}

/// 업그레이드 레벨 → 실제 능력치.
class Stats {
  const Stats({
    required this.attack,
    required this.attacksPerSecond,
    required this.critChance,
    required this.goldMultiplier,
    required this.captureRate,
  });

  factory Stats.fromLevels(Map<UpgradeType, int> levels) {
    int lv(UpgradeType t) => levels[t] ?? 0;
    return Stats(
      attack: 10 + 5.0 * lv(UpgradeType.attack),
      attacksPerSecond: 1.0 + 0.1 * lv(UpgradeType.attackSpeed),
      critChance: min(1.0, 0.05 + 0.01 * lv(UpgradeType.critChance)),
      goldMultiplier: 1.0 + 0.05 * lv(UpgradeType.goldGain),
      captureRate: 0.005 + 0.0005 * lv(UpgradeType.captureRate),
    );
  }

  final double attack;
  final double attacksPerSecond;
  final double critChance;
  final double goldMultiplier;
  final double captureRate;

  /// 치명타 기대값을 반영한 초당 피해량. 화면 표시와 오프라인 보상 계산에 쓴다.
  double dps(BalanceConfig config) =>
      attack * (1 + critChance * (config.critMultiplier - 1)) * attacksPerSecond;
}
