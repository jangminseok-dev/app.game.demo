import 'dart:math';

import 'balance_config.dart';
import 'formulas.dart';

/// 던전이 주는 재화. 재화 하나에 소비처 하나를 붙인다(시장 분석 4장).
enum DungeonCurrency {
  gold('골드', '업그레이드'),
  stone('강화석', '장비 강화'),
  eggShard('용의 알 조각', '펫 부화'),
  skillPage('스킬서 조각', '스킬 해금');

  const DungeonCurrency(this.label, this.sink);

  final String label;

  /// 이 재화를 쓰는 곳. 화면에 그대로 보여 준다.
  final String sink;
}

/// 던전 4종. 필드를 그대로 쓰고 보상 재화만 다르다.
///
/// 필드에서 골드만 나오면 성장이 한 줄로 굳는다. 던전은 재화마다 다른 소비처로 연결해
/// 오늘 무엇을 할지를 만든다.
enum DungeonType {
  goldCave('황금 동굴', DungeonCurrency.gold, 10, 8),
  stoneMine('강화석 광산', DungeonCurrency.stone, 20, 12),
  dragonNest('용의 둥지', DungeonCurrency.eggShard, 30, 15),
  ruins('고대 유적', DungeonCurrency.skillPage, 50, 20);

  const DungeonType(this.label, this.currency, this.unlockStage, this.unlockQuest);

  final String label;
  final DungeonCurrency currency;

  /// 층 난이도 기준선. 이 층보다 낮은 곳에서는 1층도 못 들어간다.
  final int unlockStage;

  /// 이 번호 퀘스트를 받아야 열린다.
  ///
  /// 해금을 퀘스트에 걸면 "다음에 뭐가 열리는가"가 퀘스트 카드 한 줄로 읽힌다.
  /// 레퍼런스도 골드 던전을 "퀘스트 23 완료시 해금"으로 잠가 둔다.
  final int unlockQuest;
}

/// 진행 중인 던전 한 판. 남은 몬스터 수와 시간만 들고 있다.
class DungeonRun {
  const DungeonRun({
    required this.type,
    required this.floor,
    required this.wavesLeft,
    required this.timeLeft,
  });

  final DungeonType type;
  final int floor;

  /// 남은 몬스터 수. 0이 되면 클리어.
  final int wavesLeft;

  /// 남은 시간(초). 0이 되면 실패이고 입장권은 돌아오지 않는다.
  final double timeLeft;

  DungeonRun copyWith({int? wavesLeft, double? timeLeft}) => DungeonRun(
        type: type,
        floor: floor,
        wavesLeft: wavesLeft ?? this.wavesLeft,
        timeLeft: timeLeft ?? this.timeLeft,
      );

  Map<String, dynamic> toJson() =>
      {'type': type.name, 'floor': floor, 'wavesLeft': wavesLeft, 'timeLeft': timeLeft};

  static DungeonRun? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final type = DungeonType.values.where((t) => t.name == j['type']).firstOrNull;
    if (type == null) return null;
    return DungeonRun(
      type: type,
      floor: (j['floor'] as num).toInt(),
      wavesLeft: (j['wavesLeft'] as num).toInt(),
      timeLeft: (j['timeLeft'] as num).toDouble(),
    );
  }
}

/// 던전 진행·입장권·던전 전용 재화.
///
/// 골드와 강화석은 이미 다른 곳([GameState.gold], [EquipmentState.stones])에 있으므로
/// 여기서는 알 조각과 스킬서 조각만 들고 있다.
class DungeonState {
  const DungeonState({
    this.cleared = const {},
    this.tickets = 3,
    this.ticketSeconds = 0,
    this.eggShards = 0,
    this.skillPages = 0,
    this.run,
  });

  static const empty = DungeonState();

  /// 던전별 최고 클리어 층. 없으면 0층(= 아직 1층도 못 깼다).
  final Map<DungeonType, int> cleared;

  /// 남은 입장권. 던전 4종이 함께 쓴다.
  final int tickets;

  /// 다음 입장권까지 쌓인 시간(초).
  final double ticketSeconds;

  final int eggShards;
  final int skillPages;

  /// 진행 중인 판. 없으면 필드에서 싸운다.
  final DungeonRun? run;

  int clearedFloor(DungeonType type) => cleared[type] ?? 0;

  /// 다음에 도전할 층. 항상 최고 클리어 층 + 1이다.
  int nextFloor(DungeonType type) => clearedFloor(type) + 1;

  /// 퀘스트를 그만큼 받았는가. 던전이 열리는 조건이다.
  bool isUnlocked(DungeonType type, int claimedQuests) => claimedQuests >= type.unlockQuest;

  /// 다음 층에 들어가는 데 필요한 최고 층.
  ///
  /// 던전이 본편보다 앞서 나가면 보상이 진행보다 커진다. 서버 세이브 검증(12장)도
  /// 같은 이유로 벌이 상한을 최고 층으로 잡으므로 여기서 함께 묶어 둔다.
  int requiredStage(DungeonType type, BalanceConfig c) =>
      max(type.unlockStage, dungeonEquivalentStage(nextFloor(type), c));

  bool canEnter(DungeonType type, int highestStage, int claimedQuests, BalanceConfig c) =>
      run == null &&
      tickets > 0 &&
      isUnlocked(type, claimedQuests) &&
      highestStage >= requiredStage(type, c);

  /// 시간이 지난 만큼 입장권을 채운다. 오프라인에도 같은 함수를 쓴다.
  DungeonState regenerate(double seconds, BalanceConfig c) {
    if (tickets >= c.dungeonTicketCap) return copyWith(ticketSeconds: 0);
    final total = ticketSeconds + seconds;
    final gained = total ~/ c.dungeonTicketSeconds;
    if (gained == 0) return copyWith(ticketSeconds: total);
    final next = min(c.dungeonTicketCap, tickets + gained);
    return copyWith(
      tickets: next,
      ticketSeconds: next >= c.dungeonTicketCap ? 0 : total % c.dungeonTicketSeconds,
    );
  }

  /// 입장권 1장을 쓰고 다음 층에 들어간다. 못 들어가면 그대로 돌려준다.
  DungeonState enter(DungeonType type, int highestStage, int claimedQuests, BalanceConfig c) {
    if (!canEnter(type, highestStage, claimedQuests, c)) return this;
    return copyWith(
      tickets: tickets - 1,
      run: DungeonRun(
        type: type,
        floor: nextFloor(type),
        wavesLeft: c.dungeonWaves,
        timeLeft: c.dungeonTimeLimit,
      ),
    );
  }

  /// 판을 끝낸다. 클리어면 층을 올리고 나가고, 실패면 그냥 나간다.
  DungeonState finish({required bool cleared}) {
    final r = run;
    if (r == null) return this;
    return copyWith(
      cleared: cleared ? {...this.cleared, r.type: max(clearedFloor(r.type), r.floor)} : null,
      clearRun: true,
    );
  }

  DungeonState addCurrency(DungeonCurrency currency, int amount) => switch (currency) {
        DungeonCurrency.eggShard => copyWith(eggShards: eggShards + amount),
        DungeonCurrency.skillPage => copyWith(skillPages: skillPages + amount),
        // 골드와 강화석은 다른 곳에 쌓인다 — 호출 측이 처리한다.
        _ => this,
      };

  DungeonState copyWith({
    Map<DungeonType, int>? cleared,
    int? tickets,
    double? ticketSeconds,
    int? eggShards,
    int? skillPages,
    DungeonRun? run,
    bool clearRun = false,
  }) {
    return DungeonState(
      cleared: cleared ?? this.cleared,
      tickets: tickets ?? this.tickets,
      ticketSeconds: ticketSeconds ?? this.ticketSeconds,
      eggShards: eggShards ?? this.eggShards,
      skillPages: skillPages ?? this.skillPages,
      run: clearRun ? null : (run ?? this.run),
    );
  }

  Map<String, dynamic> toJson() => {
        'cleared': {for (final e in cleared.entries) e.key.name: e.value},
        'tickets': tickets,
        'ticketSeconds': ticketSeconds,
        'eggShards': eggShards,
        'skillPages': skillPages,
        if (run != null) 'run': run!.toJson(),
      };

  factory DungeonState.fromJson(Map<String, dynamic> j) {
    final cleared = <DungeonType, int>{};
    for (final e in (j['cleared'] as Map<String, dynamic>? ?? const {}).entries) {
      final type = DungeonType.values.where((t) => t.name == e.key).firstOrNull;
      if (type != null) cleared[type] = (e.value as num).toInt();
    }
    return DungeonState(
      cleared: cleared,
      tickets: (j['tickets'] as num? ?? 3).toInt(),
      ticketSeconds: (j['ticketSeconds'] as num? ?? 0).toDouble(),
      eggShards: (j['eggShards'] as num? ?? 0).toInt(),
      skillPages: (j['skillPages'] as num? ?? 0).toInt(),
      run: DungeonRun.fromJson(j['run'] as Map<String, dynamic>?),
    );
  }
}

/// 던전 층을 필드 층으로 환산한다. 난이도와 보상 모두 이 값을 기준으로 계산한다.
int dungeonEquivalentStage(int floor, BalanceConfig c) => floor * c.dungeonStagesPerFloor;

double dungeonMonsterHp(int floor, BalanceConfig c) =>
    monsterHp(dungeonEquivalentStage(floor, c), c) * c.dungeonHpMultiplier;

/// 한 층을 깼을 때 주는 양. 골드만 자릿수가 다르므로 따로 계산한다.
double dungeonReward(DungeonType type, int floor, BalanceConfig c) =>
    type.currency == DungeonCurrency.gold
        ? goldReward(dungeonEquivalentStage(floor, c), c) * c.dungeonGoldMultiplier
        : c.dungeonMaterialBase + c.dungeonMaterialPerFloor * floor;
