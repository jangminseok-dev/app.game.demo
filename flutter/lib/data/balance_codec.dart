import '../domain/balance_config.dart';
import '../domain/upgrade.dart';

/// 서버 `GET /masterdata/balance` 응답 ↔ [BalanceConfig]. 로컬 캐시에도 같은 형식으로 둔다.
BalanceConfig balanceFromJson(Map<String, dynamic> j) => BalanceConfig(
      version: (j['version'] as num).toInt(),
      monsterHpBase: (j['monsterHpBase'] as num).toDouble(),
      monsterHpGrowth: (j['monsterHpGrowth'] as num).toDouble(),
      bossHpMultiplier: (j['bossHpMultiplier'] as num).toDouble(),
      bossTimeLimit: (j['bossTimeLimit'] as num).toDouble(),
      goldBase: (j['goldBase'] as num).toDouble(),
      goldGrowth: (j['goldGrowth'] as num).toDouble(),
      bossGoldMultiplier: (j['bossGoldMultiplier'] as num).toDouble(),
      upgradeCostGrowth: (j['upgradeCostGrowth'] as num).toDouble(),
      killsPerStage: (j['killsPerStage'] as num).toInt(),
      critMultiplier: (j['critMultiplier'] as num).toDouble(),
      offlineCapSeconds: (j['offlineCapSeconds'] as num).toDouble(),
      offlineEfficiency: (j['offlineEfficiency'] as num).toDouble(),
      offlineMinSeconds: (j['offlineMinSeconds'] as num).toDouble(),
      bossCaptureMultiplier: (j['bossCaptureMultiplier'] as num?)?.toDouble() ?? 4.0,
      maxStars: (j['maxStars'] as num?)?.toInt() ?? 5,
      baseCaptureRate: (j['baseCaptureRate'] as num?)?.toDouble() ?? 0.005,
      captureRatePerLevel: (j['captureRatePerLevel'] as num?)?.toDouble() ?? 0.0005,
      capturePityKills: (j['capturePityKills'] as num?)?.toInt() ?? 400,
      attackBase: (j['attackBase'] as num?)?.toDouble() ?? 10,
      attackPerLevel: (j['attackPerLevel'] as num?)?.toDouble() ?? 5,
      attackSpeedBase: (j['attackSpeedBase'] as num?)?.toDouble() ?? 1.0,
      attackSpeedPerLevel: (j['attackSpeedPerLevel'] as num?)?.toDouble() ?? 0.1,
      critBase: (j['critBase'] as num?)?.toDouble() ?? 0.05,
      critPerLevel: (j['critPerLevel'] as num?)?.toDouble() ?? 0.01,
      goldMultiplierPerLevel: (j['goldMultiplierPerLevel'] as num?)?.toDouble() ?? 0.05,
      upgradeBaseCosts: _costs(j['upgradeBaseCosts'] as Map<String, dynamic>?),
    );

Map<UpgradeType, double> _costs(Map<String, dynamic>? raw) {
  if (raw == null) return const BalanceConfig().upgradeBaseCosts;
  return {
    for (final t in UpgradeType.values)
      t: (raw[t.name] as num?)?.toDouble() ?? const BalanceConfig().upgradeBaseCosts[t]!,
  };
}

Map<String, dynamic> balanceToJson(BalanceConfig c) => {
      'version': c.version,
      'monsterHpBase': c.monsterHpBase,
      'monsterHpGrowth': c.monsterHpGrowth,
      'bossHpMultiplier': c.bossHpMultiplier,
      'bossTimeLimit': c.bossTimeLimit,
      'goldBase': c.goldBase,
      'goldGrowth': c.goldGrowth,
      'bossGoldMultiplier': c.bossGoldMultiplier,
      'upgradeCostGrowth': c.upgradeCostGrowth,
      'killsPerStage': c.killsPerStage,
      'critMultiplier': c.critMultiplier,
      'offlineCapSeconds': c.offlineCapSeconds,
      'offlineEfficiency': c.offlineEfficiency,
      'offlineMinSeconds': c.offlineMinSeconds,
      'bossCaptureMultiplier': c.bossCaptureMultiplier,
      'maxStars': c.maxStars,
      'baseCaptureRate': c.baseCaptureRate,
      'captureRatePerLevel': c.captureRatePerLevel,
      'capturePityKills': c.capturePityKills,
      'attackBase': c.attackBase,
      'attackPerLevel': c.attackPerLevel,
      'attackSpeedBase': c.attackSpeedBase,
      'attackSpeedPerLevel': c.attackSpeedPerLevel,
      'critBase': c.critBase,
      'critPerLevel': c.critPerLevel,
      'goldMultiplierPerLevel': c.goldMultiplierPerLevel,
      'upgradeBaseCosts': {for (final e in c.upgradeBaseCosts.entries) e.key.name: e.value},
    };
