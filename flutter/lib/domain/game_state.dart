import 'balance_config.dart';
import 'codex.dart';
import 'dungeon.dart';
import 'equipment.dart';
import 'formulas.dart' as formulas;
import 'hatchery.dart';
import 'pet.dart';
import 'quest.dart';
import 'upgrade.dart';

/// 게임 진행 상태. 불변 객체이며 [BattleEngine]이 새 상태를 만들어 돌려준다.
class GameState {
  const GameState({
    required this.stage,
    required this.highestStage,
    required this.gold,
    required this.levels,
    required this.monsterHp,
    required this.monsterMaxHp,
    required this.isBoss,
    required this.bossTimeLeft,
    required this.killsOnStage,
    required this.attackTimer,
    required this.totalKills,
    this.monsterId = 1,
    this.killLog = const {},
    this.bossKillLog = const {},
    this.codex = const {},
    this.pity = const {},
    this.passives = Passives.none,
    this.equipment = EquipmentState.empty,
    this.dungeon = DungeonState.empty,
    this.quests = QuestState.empty,
    this.pets = PetState.empty,
    this.hatchery = HatcheryState.empty,
  });

  factory GameState.initial(BalanceConfig config) {
    final hp = formulas.monsterHp(1, config);
    return GameState(
      stage: 1,
      highestStage: 1,
      gold: 0,
      levels: const {},
      monsterHp: hp,
      monsterMaxHp: hp,
      isBoss: false,
      bossTimeLeft: 0,
      killsOnStage: 0,
      attackTimer: 0,
      totalKills: 0,
    );
  }

  final int stage;
  final int highestStage;
  final double gold;
  final Map<UpgradeType, int> levels;
  final double monsterHp;
  final double monsterMaxHp;
  final bool isBoss;
  final double bossTimeLeft;
  final int killsOnStage;

  /// 다음 공격까지 누적된 시간(초). 공격속도가 프레임보다 빠를 때를 위해 둔다.
  final double attackTimer;
  final int totalKills;

  /// 지금 싸우는 몬스터(마스터 데이터 id).
  final int monsterId;

  /// 마지막 서버 동기화 이후 몬스터별 처치 수. 서버가 포획을 굴리는 근거이며, 수락되면 비운다.
  final Map<int, int> killLog;
  final Map<int, int> bossKillLog;

  /// 도감(몬스터 id → 성급). 서버가 정본이며 전생해도 남는다.
  final Map<int, int> codex;

  /// 몬스터별 천장 진행(마지막 포획 이후 서버가 센 처치 수). 표시용이며 서버 응답으로만 갱신한다.
  final Map<int, int> pity;

  /// [codex]에서 계산한 패시브 합계. codex가 바뀔 때 [BattleEngine.withCodex]가 함께 갱신한다.
  final Passives passives;

  /// 장비·강화석·강화 레벨. 공격력에 배수로 곱해진다.
  final EquipmentState equipment;

  /// 던전 진행·입장권·던전 재화. [DungeonState.run]이 있으면 필드가 아니라 던전에서 싸운다.
  final DungeonState dungeon;

  /// 받은 퀘스트 수. 진행도는 저장하지 않고 이 상태에서 그때그때 계산한다.
  final QuestState quests;

  /// 가진 펫과 데리고 다니는 펫. 능력치에 곱해진다.
  final PetState pets;

  /// 부화 3칸과 탐험 3칸. 시간이 지나야 끝난다.
  final HatcheryState hatchery;

  Stats statsWith(BalanceConfig config) => Stats.fromLevels(levels, config, passives)
      .scaledBy(equipment.powerWith(config))
      .withPet(pets);

  int levelOf(UpgradeType type) => levels[type] ?? 0;

  int starsOf(int monsterId) => codex[monsterId] ?? 0;

  GameState copyWith({
    int? stage,
    int? highestStage,
    double? gold,
    Map<UpgradeType, int>? levels,
    double? monsterHp,
    double? monsterMaxHp,
    bool? isBoss,
    double? bossTimeLeft,
    int? killsOnStage,
    double? attackTimer,
    int? totalKills,
    int? monsterId,
    Map<int, int>? killLog,
    Map<int, int>? bossKillLog,
    Map<int, int>? codex,
    Map<int, int>? pity,
    Passives? passives,
    EquipmentState? equipment,
    DungeonState? dungeon,
    QuestState? quests,
    PetState? pets,
    HatcheryState? hatchery,
  }) {
    return GameState(
      stage: stage ?? this.stage,
      highestStage: highestStage ?? this.highestStage,
      gold: gold ?? this.gold,
      levels: levels ?? this.levels,
      monsterHp: monsterHp ?? this.monsterHp,
      monsterMaxHp: monsterMaxHp ?? this.monsterMaxHp,
      isBoss: isBoss ?? this.isBoss,
      bossTimeLeft: bossTimeLeft ?? this.bossTimeLeft,
      killsOnStage: killsOnStage ?? this.killsOnStage,
      attackTimer: attackTimer ?? this.attackTimer,
      totalKills: totalKills ?? this.totalKills,
      monsterId: monsterId ?? this.monsterId,
      killLog: killLog ?? this.killLog,
      bossKillLog: bossKillLog ?? this.bossKillLog,
      codex: codex ?? this.codex,
      pity: pity ?? this.pity,
      passives: passives ?? this.passives,
      equipment: equipment ?? this.equipment,
      dungeon: dungeon ?? this.dungeon,
      quests: quests ?? this.quests,
      pets: pets ?? this.pets,
      hatchery: hatchery ?? this.hatchery,
    );
  }
}
