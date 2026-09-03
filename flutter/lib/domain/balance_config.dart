/// 밸런스 계수. GAME_DESIGN.md 4장의 공식 계수를 한 곳에 모은다.
///
/// 서버 마스터 데이터(`GET /masterdata/balance`)에서 받아 채운다. 내장 기본값은
/// 서버가 안 닿을 때의 폴백이며 backend `resources/balance.json`과 같은 값이다.
class BalanceConfig {
  const BalanceConfig({
    this.version = 0,
    this.monsterHpBase = 10,
    this.monsterHpGrowth = 1.18,
    this.bossHpMultiplier = 10,
    this.bossTimeLimit = 30,
    this.goldBase = 5,
    this.goldGrowth = 1.15,
    this.bossGoldMultiplier = 10,
    this.upgradeCostGrowth = 1.09,
    this.killsPerStage = 10,
    this.critMultiplier = 2.0,
    this.offlineCapSeconds = 8 * 3600,
    this.offlineEfficiency = 0.5,
    this.offlineMinSeconds = 60,
    this.bossCaptureMultiplier = 4.0,
    this.maxStars = 5,
  });

  /// 서버 마스터 데이터 버전. 내장 기본값은 0 — 서버 값이 오면 항상 갱신된다.
  final int version;

  final double monsterHpBase;
  final double monsterHpGrowth;
  final double bossHpMultiplier;
  final double bossTimeLimit;
  final double goldBase;
  final double goldGrowth;
  final double bossGoldMultiplier;
  final double upgradeCostGrowth;
  final int killsPerStage;
  final double critMultiplier;

  /// 오프라인 보상 (GAME_DESIGN 8장): 상한 8시간, 효율 50%.
  final double offlineCapSeconds;
  final double offlineEfficiency;

  /// 이보다 짧은 이탈은 보상 없음. 팝업이 너무 자주 뜨는 것을 막는다(가정값).
  final double offlineMinSeconds;

  /// 포획 (GAME_DESIGN 6장): 보스는 별도 배율, 성급 상한.
  final double bossCaptureMultiplier;
  final int maxStars;
}
