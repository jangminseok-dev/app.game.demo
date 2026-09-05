import 'dart:math';

import 'balance_config.dart';
import 'codex.dart';
import 'pet.dart';
import 'spirit.dart';
import 'summon.dart';

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

  /// 유물 네 칸과 용화 단계를 얹는다.
  ///
  /// 용화 배수는 **공격력에만** 곱한다. DPS는 공격력 × 공속이라 둘 다 곱하면
  /// 배수가 제곱으로 들어가 유물이 장비를 이긴다(스펙 3.4). 치명타는 0~1 확률이라
  /// 곱하면 상한을 넘기므로 날개 보정을 더하고 1.0으로 묶는다.
  Stats withRelics(SummonState summon, BalanceConfig c) {
    if (summon.totalStars == 0) return this;
    final m = dragonMultiplier(summon.dragonStage, c);
    return Stats(
      attack: attack * (1 + relicBonus(summon.starsOf(RelicSlot.horn))) * m,
      attacksPerSecond: attacksPerSecond * (1 + relicBonus(summon.starsOf(RelicSlot.tail))),
      critChance: min(1.0, critChance + relicBonus(summon.starsOf(RelicSlot.wing))),
      goldMultiplier: goldMultiplier,
    );
  }

  /// 데리고 다니는 정령의 평소 보정. 공격력에만 걸린다 —
  /// 정령의 값어치는 평소가 아니라 나올 때다.
  Stats withSpirit(SpiritState spirits, BalanceConfig c) {
    final bonus = spiritPassive(spirits.activeStars, c);
    if (bonus == 0) return this;
    return Stats(
      attack: attack * (1 + bonus),
      attacksPerSecond: attacksPerSecond,
      critChance: critChance,
      goldMultiplier: goldMultiplier,
    );
  }

  /// 치명타 기대값을 반영한 초당 피해량. 화면 표시와 오프라인 보상 계산에 쓴다.
  double dps(BalanceConfig config) =>
      attack * (1 + critChance * (config.critMultiplier - 1)) * attacksPerSecond;
}

/// 기본 포획률(0~1). 계수는 마스터 데이터(4장). 실제 판정은 서버가 희귀도·보스 배율을 곱해 굴린다.
double captureRateOf(Map<UpgradeType, int> levels, BalanceConfig c, [Passives p = Passives.none]) =>
    (c.baseCaptureRate + c.captureRatePerLevel * (levels[UpgradeType.captureRate] ?? 0)) * (1 + p.capture / 100);
