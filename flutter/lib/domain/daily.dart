import 'game_state.dart';
import 'quest.dart';

/// 오늘 하루치 과제 3개. 자정이 지나면 새로 시작한다.
///
/// 번호 퀘스트가 "어디까지 왔는가"라면 일일 과제는 "오늘 무엇을 했는가"다.
/// 둘이 섞이면 둘 다 흐려지므로 표를 따로 둔다.
enum DailyGoal {
  kills('오늘 몬스터 처치', 100, RewardKind.summonStone, 30),
  dungeonFloors('오늘 던전 층 클리어', 1, RewardKind.ticket, 1),
  crafts('오늘 장비 제작', 3, RewardKind.stone, 60);

  const DailyGoal(this.label, this.target, this.reward, this.rewardAmount);

  final String label;
  final int target;
  final RewardKind reward;
  final int rewardAmount;
}

/// 오늘 날짜와 하루 시작 시점의 눈금, 그리고 이미 받은 과제.
///
/// 진행도를 따로 세지 않고 "하루 시작값과의 차이"로 잰다. 번호 퀘스트와 같은 방식이라
/// 저장이 어긋날 일이 없다.
class DailyState {
  const DailyState({
    this.day = -1,
    this.killsAtStart = 0,
    this.floorsAtStart = 0,
    this.craftsAtStart = 0,
    this.claimed = const {},
  });

  static const empty = DailyState();

  final int day;
  final int killsAtStart;
  final int floorsAtStart;
  final int craftsAtStart;

  /// 오늘 이미 받은 과제.
  final Set<DailyGoal> claimed;

  bool isClaimed(DailyGoal goal) => claimed.contains(goal);

  DailyState claim(DailyGoal goal) => copyWith(claimed: {...claimed, goal});

  DailyState copyWith({
    int? day,
    int? killsAtStart,
    int? floorsAtStart,
    int? craftsAtStart,
    Set<DailyGoal>? claimed,
  }) {
    return DailyState(
      day: day ?? this.day,
      killsAtStart: killsAtStart ?? this.killsAtStart,
      floorsAtStart: floorsAtStart ?? this.floorsAtStart,
      craftsAtStart: craftsAtStart ?? this.craftsAtStart,
      claimed: claimed ?? this.claimed,
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'killsAtStart': killsAtStart,
        'floorsAtStart': floorsAtStart,
        'craftsAtStart': craftsAtStart,
        'claimed': [for (final g in claimed) g.name],
      };

  factory DailyState.fromJson(Map<String, dynamic> j) => DailyState(
        day: (j['day'] as num? ?? -1).toInt(),
        killsAtStart: (j['killsAtStart'] as num? ?? 0).toInt(),
        floorsAtStart: (j['floorsAtStart'] as num? ?? 0).toInt(),
        craftsAtStart: (j['craftsAtStart'] as num? ?? 0).toInt(),
        claimed: {
          for (final name in (j['claimed'] as List? ?? []))
            ?DailyGoal.values.where((g) => g.name == name).firstOrNull,
        },
      );
}

/// 상태에서 읽는 오늘 진행도. 하루 시작값과의 차이다.
int dailyProgress(DailyGoal goal, GameState s) {
  final d = s.daily;
  return switch (goal) {
    DailyGoal.kills => s.totalKills - d.killsAtStart,
    DailyGoal.dungeonFloors => s.dungeon.cleared.values.fold(0, (a, b) => a + b) - d.floorsAtStart,
    // 제작 숙련도는 두드릴 때마다 1씩 오른다. 그래서 그대로 제작 횟수다.
    DailyGoal.crafts => s.equipment.craftLevel - d.craftsAtStart,
  }.clamp(0, 1 << 30).toInt();
}

bool dailyReady(DailyGoal goal, GameState s) =>
    !s.daily.isClaimed(goal) && dailyProgress(goal, s) >= goal.target;

/// 받을 수 있는 과제가 하나라도 있는가. 화면의 빨간 점 조건이다.
bool anyDailyReady(GameState s) => DailyGoal.values.any((g) => dailyReady(g, s));
