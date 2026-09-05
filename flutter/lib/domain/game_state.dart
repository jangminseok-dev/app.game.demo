import 'attendance.dart';
import 'dart:math';

import 'balance_config.dart';
import 'codex.dart';
import 'daily.dart';
import 'dungeon.dart';
import 'equipment.dart';
import 'formulas.dart' as formulas;
import 'field.dart';
import 'hatchery.dart';
import 'monster_unit.dart';
import 'pet.dart';
import 'quest.dart';
import 'skill.dart';
import 'spirit.dart';
import 'summon.dart';
import 'upgrade.dart';

/// 게임 진행 상태. 불변 객체이며 [BattleEngine]이 새 상태를 만들어 돌려준다.
class GameState {
  const GameState({
    required this.stage,
    required this.highestStage,
    required this.gold,
    required this.levels,
    required this.wave,
    required this.isBoss,
    required this.bossTimeLeft,
    required this.killsOnStage,
    required this.attackTimer,
    required this.totalKills,
    this.waveSeq = 0,
    this.heroHp = -1,
    this.heroMp = -1,
    this.heroX = heroHomeX,
    this.heroY = heroHomeY,
    this.reviveLeft = 0,
    this.stageTimeLeft = -1,
    this.stageFailCount = 0,
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
    this.skills = SkillState.empty,
    this.attendance = AttendanceState.empty,
    this.daily = DailyState.empty,
    this.summon = SummonState.empty,
    this.spirits = SpiritState.empty,
  });

  factory GameState.initial(BalanceConfig config) {
    final hp = formulas.monsterHp(1, config);
    return GameState(
      stage: 1,
      highestStage: 1,
      gold: 0,
      levels: const {},
      wave: [
        for (var i = 0; i < config.waveSizeMin; i++)
          MonsterUnit(
            key: i,
            id: 1,
            hp: hp,
            maxHp: hp,
            x: monsterSpawnX + i * 22,
            y: fieldTopY + (fieldBottomY - fieldTopY) * i / config.waveSizeMin,
          ),
      ],
      waveSeq: config.waveSizeMin,
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

  /// 지금 서 있는 몬스터들. 앞에서부터 때린다. 비어 있으면 다음 무리를 부른다.
  final List<MonsterUnit> wave;

  /// 다음 몬스터에게 매길 번호. 무대가 같은 몬스터를 알아보는 데 쓴다.
  final int waveSeq;

  final bool isBoss;

  // ── 주인공. 체력·마력과 서 있는 자리.

  /// 남은 체력. -1은 "아직 채운 적 없음"이며 [maxHeroHp]로 채워진다.
  final double heroHp;

  /// 남은 마력. -1은 "아직 채운 적 없음".
  final double heroMp;

  final double heroX;
  final double heroY;

  /// 쓰러진 뒤 다시 일어서기까지 남은 시간(초). 0보다 크면 싸울 수 없다.
  final double reviveLeft;

  bool get isDown => reviveLeft > 0;

  /// 이 층에 남은 시간(초). -1은 "아직 시작 안 함"이며 첫 틱에 채워진다.
  final double stageTimeLeft;

  /// 시간을 넘겨 밀린 횟수. 화면이 "벽에 닿았다"를 알아채는 데 쓴다.
  final int stageFailCount;

  double stageTimeLeftOr(BalanceConfig c) => stageTimeLeft < 0 ? c.stageTimeLimit : stageTimeLeft;

  double stageTimeRatio(BalanceConfig c) =>
      (stageTimeLeftOr(c) / c.stageTimeLimit).clamp(0.0, 1.0);

  /// 업그레이드에 투자한 만큼 몸도 단단해진다.
  int get totalUpgradeLevels => levels.values.fold(0, (a, b) => a + b);

  /// 비늘은 여기 걸린다. `Stats` 에는 체력 칸이 없다.
  /// 용화 배수는 체력에도 곱한다 — 스펙 3.3의 "전 스탯"에서 빠질 이유가 없다.
  double maxHeroHp(BalanceConfig c) =>
      (c.heroHpBase + c.heroHpPerLevel * totalUpgradeLevels) *
      pow(c.heroHpStageGrowth, highestStage - 1) *
      (1 + relicBonus(summon.starsOf(RelicSlot.scale))) *
      dragonMultiplier(summon.dragonStage, c);

  double maxHeroMp(BalanceConfig c) => c.heroMpBase + c.heroMpPerLevel * totalUpgradeLevels;

  /// 저장에 없던 값(-1)은 가득 찬 것으로 본다.
  double heroHpOr(BalanceConfig c) => heroHp < 0 ? maxHeroHp(c) : heroHp;
  double heroMpOr(BalanceConfig c) => heroMp < 0 ? maxHeroMp(c) : heroMp;

  double heroHpRatio(BalanceConfig c) => (heroHpOr(c) / maxHeroHp(c)).clamp(0.0, 1.0);
  double heroMpRatio(BalanceConfig c) => (heroMpOr(c) / maxHeroMp(c)).clamp(0.0, 1.0);

  /// 주인공에게 가장 가까운 살아 있는 몬스터. 없으면 null.
  MonsterUnit? get nearestMonster {
    MonsterUnit? best;
    var bestDistance = double.infinity;
    for (final m in wave) {
      final d = distanceBetween(heroX, heroY, m.x, m.y);
      if (d < bestDistance) {
        bestDistance = d;
        best = m;
      }
    }
    return best;
  }

  /// 평타와 화면 표시가 보는 몬스터 — 가장 가까운 것이다.
  MonsterUnit? get front => nearestMonster;

  /// 맨 앞 몬스터의 체력만 바꾼 상태.
  GameState withFrontHp(double hp) =>
      wave.isEmpty ? this : copyWith(wave: [wave.first.copyWith(hp: hp), ...wave.skip(1)]);

  /// 화면·저장·서버가 쓰는 대표값. 무리 전투 이전과 같은 이름으로 남겨 둔다.
  double get monsterHp => front?.hp ?? 0;
  double get monsterMaxHp => front?.maxHp ?? 0;
  int get monsterId => front?.id ?? 1;
  final double bossTimeLeft;
  final int killsOnStage;

  /// 다음 공격까지 누적된 시간(초). 공격속도가 프레임보다 빠를 때를 위해 둔다.
  final double attackTimer;
  final int totalKills;

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

  /// 해금·장착한 스킬과 남은 대기 시간.
  final SkillState skills;

  /// 출석부. 하루 한 번 받는다.
  final AttendanceState attendance;

  /// 오늘치 과제 3개.
  final DailyState daily;

  /// 소환석과 유물 네 칸.
  final SummonState summon;

  /// 정령 — 가진 것·데리고 다니는 하나·게이지.
  final SpiritState spirits;

  Stats statsWith(BalanceConfig config) => Stats.fromLevels(levels, config, passives)
      .scaledBy(equipment.powerWith(config))
      .withPet(pets)
      .withRelics(summon, config);

  int levelOf(UpgradeType type) => levels[type] ?? 0;

  int starsOf(int monsterId) => codex[monsterId] ?? 0;

  GameState copyWith({
    int? stage,
    int? highestStage,
    double? gold,
    Map<UpgradeType, int>? levels,
    List<MonsterUnit>? wave,
    int? waveSeq,
    double? heroHp,
    double? heroMp,
    double? heroX,
    double? heroY,
    double? reviveLeft,
    double? stageTimeLeft,
    int? stageFailCount,
    bool? isBoss,
    double? bossTimeLeft,
    int? killsOnStage,
    double? attackTimer,
    int? totalKills,
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
    SkillState? skills,
    AttendanceState? attendance,
    DailyState? daily,
    SummonState? summon,
    SpiritState? spirits,
  }) {
    return GameState(
      stage: stage ?? this.stage,
      highestStage: highestStage ?? this.highestStage,
      gold: gold ?? this.gold,
      levels: levels ?? this.levels,
      wave: wave ?? this.wave,
      waveSeq: waveSeq ?? this.waveSeq,
      heroHp: heroHp ?? this.heroHp,
      heroMp: heroMp ?? this.heroMp,
      heroX: heroX ?? this.heroX,
      heroY: heroY ?? this.heroY,
      reviveLeft: reviveLeft ?? this.reviveLeft,
      stageTimeLeft: stageTimeLeft ?? this.stageTimeLeft,
      stageFailCount: stageFailCount ?? this.stageFailCount,
      isBoss: isBoss ?? this.isBoss,
      bossTimeLeft: bossTimeLeft ?? this.bossTimeLeft,
      killsOnStage: killsOnStage ?? this.killsOnStage,
      attackTimer: attackTimer ?? this.attackTimer,
      totalKills: totalKills ?? this.totalKills,
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
      skills: skills ?? this.skills,
      attendance: attendance ?? this.attendance,
      daily: daily ?? this.daily,
      summon: summon ?? this.summon,
      spirits: spirits ?? this.spirits,
    );
  }
}
