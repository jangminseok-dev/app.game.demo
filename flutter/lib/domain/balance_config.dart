/// 밸런스 계수. GAME_DESIGN.md 4장의 공식 계수를 한 곳에 모은다.
///
/// 지금은 상수지만, 4장 원칙대로 나중에 서버 마스터 데이터로 교체된다.
/// 그래서 `const` 생성자로 두고 도메인 함수는 전부 이 객체를 받는다.
class BalanceConfig {
  const BalanceConfig({
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
  });

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
}
