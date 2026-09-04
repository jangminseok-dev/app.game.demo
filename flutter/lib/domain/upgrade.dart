import 'dart:math';

import 'balance_config.dart';
import 'codex.dart';
import 'pet.dart';

/// 골드로 사는 능력치 업그레이드 5종. GAME_DESIGN.md 3장·17장.
///
/// 능력치는 레벨에 선형으로 붙고(4장), 비용만 지수로 오른다.
enum UpgradeType {
  attack('공격력'),
  attackSpeed('공격속도'),
  critChance('치명타'),
  goldGain('골드획득'),
  captureRate('포획률');

  const UpgradeType(this.label);

  final String label;

  /// 비용 = 기본 비용(마스터 데이터) × 성장률^레벨.
  double cost(int level, BalanceConfig config) =>
      config.upgradeBaseCosts[this]! * pow(config.upgradeCostGrowth, level);
}

/// 업그레이드 레벨 + 도감 패시브 → 실제 능력치. 서버 `formulas.stats_of`와 같은 식.
class Stats {
  const Stats({
    required this.attack,
    required this.attacksPerSecond,
    required this.critChance,
    required this.goldMultiplier,
  });

  factory Stats.fromLevels(Map<UpgradeType, int> levels, BalanceConfig c, [Passives p = Passives.none]) {
    int lv(UpgradeType t) => levels[t] ?? 0;
    return Stats(
      attack: (c.attackBase + c.attackPerLevel * lv(UpgradeType.attack)) * (1 + p.attack / 100),
      attacksPerSecond: (c.attackSpeedBase + c.attackSpeedPerLevel * lv(UpgradeType.attackSpeed)) * (1 + p.attackSpeed / 100),
      critChance: min(1.0, c.critBase + c.critPerLevel * lv(UpgradeType.critChance) + p.crit / 100),
      goldMultiplier: (1.0 + c.goldMultiplierPerLevel * lv(UpgradeType.goldGain)) * (1 + p.gold / 100),
    );
  }

  final double attack;
  final double attacksPerSecond;
  final double critChance;
  final double goldMultiplier;

  /// 장비·강화가 주는 배수를 공격력에만 곱한다. 공속·치명·골드는 건드리지 않는다.
  Stats scaledBy(double multiplier) => multiplier == 1
      ? this
      : Stats(
          attack: attack * multiplier,
          attacksPerSecond: attacksPerSecond,
          critChance: critChance,
          goldMultiplier: goldMultiplier,
        );

  /// 데리고 다니는 펫의 능력을 얹는다. 펫이 없으면 그대로다.
  Stats withPet(PetState pets) {
    if (pets.active == null) return this;
    return Stats(
      attack: attack * (1 + pets.bonusOf(PetBonus.attack)),
      attacksPerSecond: attacksPerSecond,
      critChance: min(1.0, critChance + pets.bonusOf(PetBonus.crit)),
      goldMultiplier: goldMultiplier * (1 + pets.bonusOf(PetBonus.gold)),
    );
  }

  /// 치명타 기대값을 반영한 초당 피해량. 화면 표시와 오프라인 보상 계산에 쓴다.
  double dps(BalanceConfig config) =>
      attack * (1 + critChance * (config.critMultiplier - 1)) * attacksPerSecond;
}

/// 기본 포획률(0~1). 계수는 마스터 데이터(4장). 실제 판정은 서버가 희귀도·보스 배율을 곱해 굴린다.
double captureRateOf(Map<UpgradeType, int> levels, BalanceConfig c, [Passives p = Passives.none]) =>
    (c.baseCaptureRate + c.captureRatePerLevel * (levels[UpgradeType.captureRate] ?? 0)) * (1 + p.capture / 100);
