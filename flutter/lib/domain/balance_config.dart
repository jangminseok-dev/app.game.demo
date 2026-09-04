import 'upgrade.dart';

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
    this.offlineCapSeconds = 12 * 3600,
    this.offlineEfficiency = 0.5,
    this.offlineMinSeconds = 60,
    this.bossCaptureMultiplier = 4.0,
    this.maxStars = 5,
    this.baseCaptureRate = 0.005,
    this.captureRatePerLevel = 0.0005,
    this.capturePityKills = 400,
    this.attackBase = 10,
    this.attackPerLevel = 5,
    this.attackSpeedBase = 1.0,
    this.attackSpeedPerLevel = 0.1,
    this.critBase = 0.05,
    this.critPerLevel = 0.01,
    this.goldMultiplierPerLevel = 0.05,
    this.equipFieldDropChance = 0.08,
    this.equipBossDropChance = 1.0,
    this.equipStagesPerTier = 50,
    this.equipGearCoefficient = 0.02,
    this.equipEnhancePerLevel = 0.03,
    this.dungeonTicketSeconds = 8 * 3600,
    this.dungeonTicketCap = 12,
    this.dungeonWaves = 5,
    this.dungeonTimeLimit = 90,
    this.dungeonStagesPerFloor = 5,
    this.dungeonHpMultiplier = 1.4,
    this.dungeonGoldMultiplier = 40,
    this.dungeonMaterialBase = 5,
    this.dungeonMaterialPerFloor = 3,
    this.expeditionSeconds = 4 * 3600,
    this.expeditionGoldMultiplier = 300,
    this.expeditionShards = 25,
    this.adSpeedUpSeconds = 30 * 60,
    this.upgradeBaseCosts = const {
      UpgradeType.attack: 10,
      UpgradeType.attackSpeed: 25,
      UpgradeType.critChance: 50,
      UpgradeType.goldGain: 40,
      UpgradeType.captureRate: 100,
    },
  });

  /// 서버 마스터 데이터 버전. 내장 기본값은 0 — 서버 값이 오면 항상 갱신된다.
  final int version;

  // ── 장비. 밸런스는 나중에 한 번에 잡는다. 수치는 전부 여기와 서버 마스터 데이터에만 둔다.

  /// 일반 몬스터 처치 시 장비가 뜰 확률.
  final double equipFieldDropChance;

  /// 보스 처치 시 장비가 뜰 확률.
  final double equipBossDropChance;

  /// 몇 층마다 장비 티어가 오르는가.
  final int equipStagesPerTier;

  /// 착용 장비 합계에 곱하는 계수. 크면 4장의 '벽' 원칙이 깨진다(wall_simulation_test가 지킨다).
  final double equipGearCoefficient;

  /// 강화 1레벨당 공격력 배수 증가분.
  final double equipEnhancePerLevel;

  // ── 던전. 필드를 그대로 쓰되 입장권을 쓰고 층 보상만 다르다.

  /// 입장권 1장이 차는 데 걸리는 시간(초). 하루 3장.
  final double dungeonTicketSeconds;

  /// 쌓아 둘 수 있는 입장권 최대치. 며칠 못 들어와도 손해가 없어야 한다.
  final int dungeonTicketCap;

  /// 한 층에서 잡아야 하는 몬스터 수.
  final int dungeonWaves;

  /// 한 층의 제한 시간(초). 넘기면 실패이고 입장권은 돌려주지 않는다.
  final double dungeonTimeLimit;

  /// 던전 1층이 필드 몇 층에 해당하는가. 층 난이도 환산에 쓴다.
  final int dungeonStagesPerFloor;

  /// 같은 난이도의 필드 몬스터 대비 던전 몬스터의 체력 배수.
  final double dungeonHpMultiplier;

  /// 황금 동굴 보상 = 환산 층의 필드 골드 × 이 배수.
  final double dungeonGoldMultiplier;

  /// 재료형 던전 보상 = base + perFloor × 층.
  final double dungeonMaterialBase;
  final double dungeonMaterialPerFloor;

  // ── 부화와 탐험. 시간이 재화인 자리다.

  /// 탐험 한 번에 걸리는 시간(초).
  final double expeditionSeconds;

  /// 탐험 보상 = 보낸 시점 최고 층의 필드 골드 × 이 배수.
  final double expeditionGoldMultiplier;

  /// 탐험 한 번이 주는 알 조각.
  final int expeditionShards;

  /// 광고 한 편이 줄여 주는 부화 시간(초).
  final double adSpeedUpSeconds;

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

  /// 오프라인 보상 (GAME_DESIGN 8장): 상한 12시간, 효율 50%.
  final double offlineCapSeconds;
  final double offlineEfficiency;

  /// 이보다 짧은 이탈은 보상 없음. 팝업이 너무 자주 뜨는 것을 막는다(가정값).
  final double offlineMinSeconds;

  /// 포획 (GAME_DESIGN 6장): 보스는 별도 배율, 성급 상한.
  final double bossCaptureMultiplier;
  final int maxStars;

  /// 기본 포획률과 레벨당 증가. 천장은 희귀도 1.0 기준이며 실제 천장 = pity / 희귀도.
  final double baseCaptureRate;
  final double captureRatePerLevel;
  final int capturePityKills;

  /// 몬스터 희귀도에 맞춘 확정 포획 처치 수. 서버 `pity_threshold`와 같은 식.
  int pityThreshold(double rarity) => (capturePityKills / rarity).round().clamp(1, 1 << 30);

  /// 능력치 = base + perLevel × 레벨 (선형, GAME_DESIGN 4장).
  final double attackBase;
  final double attackPerLevel;
  final double attackSpeedBase;
  final double attackSpeedPerLevel;
  final double critBase;
  final double critPerLevel;
  final double goldMultiplierPerLevel;

  /// 업그레이드 종류별 레벨 0 비용. 비용 = base × upgradeCostGrowth^레벨.
  final Map<UpgradeType, double> upgradeBaseCosts;
}
