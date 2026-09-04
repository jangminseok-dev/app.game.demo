import 'balance_config.dart';
import 'game_state.dart';

/// 퀘스트가 재는 것. 전부 [GameState]에서 바로 읽을 수 있는 값이다.
///
/// 따로 진행도를 저장하지 않는다. 상태에서 계산하면 저장이 깨질 일도, 어긋날 일도 없다.
enum QuestGoal {
  stage('층 도달'),
  totalKills('누적 처치'),
  enhanceLevel('강화'),
  dungeonFloors('던전 층 클리어'),
  codexRegistered('도감 등록');

  const QuestGoal(this.label);

  final String label;
}

/// 퀘스트 보상 재화. 쌓이는 자리가 저마다 다르다.
enum RewardKind {
  gold('골드'),
  stone('강화석'),
  ticket('입장권'),
  eggShard('용의 알 조각'),
  skillPage('스킬서 조각');

  const RewardKind(this.label);

  final String label;
}

/// 번호가 붙은 퀘스트 한 줄. 앞 번호를 받아야 다음 번호가 보인다.
///
/// 레퍼런스(99강화 나무몽둥이)의 유도 방식이다. 목록을 늘어놓지 않고 "지금 할 일" 하나만
/// 보여 주면 다음에 무엇을 할지 고민할 필요가 없어진다.
class Quest {
  const Quest({
    required this.number,
    required this.goal,
    required this.target,
    required this.reward,
    required this.rewardAmount,
  });

  final int number;
  final QuestGoal goal;
  final int target;
  final RewardKind reward;
  final int rewardAmount;

  String get label => '${goal.label} $target';
}

/// 퀘스트 표 60개. 목표 5종을 돌아가며 목표치를 키운다.
///
/// 손으로 60줄을 적는 대신 규칙으로 만든다. 순서와 간격을 바꾸려면 여기만 고치면 된다.
final List<Quest> questTable = List.unmodifiable([
  for (var number = 1; number <= 60; number++) _questAt(number),
]);

Quest _questAt(int number) {
  final goal = QuestGoal.values[(number - 1) % QuestGoal.values.length];
  // 같은 목표가 몇 번째로 나오는가. 1부터 센다.
  final step = (number - 1) ~/ QuestGoal.values.length + 1;
  final target = switch (goal) {
    QuestGoal.stage => step * 10,
    QuestGoal.totalKills => step * 300,
    QuestGoal.enhanceLevel => step * 5,
    QuestGoal.dungeonFloors => step * 2,
    QuestGoal.codexRegistered => step * 3,
  };
  final reward = RewardKind.values[(number - 1) % RewardKind.values.length];
  final amount = switch (reward) {
    RewardKind.gold => 500 * step * step,
    RewardKind.stone => 20 * step,
    RewardKind.ticket => 1,
    RewardKind.eggShard => 10 * step,
    RewardKind.skillPage => 10 * step,
  };
  return Quest(number: number, goal: goal, target: target, reward: reward, rewardAmount: amount);
}

/// 받은 퀘스트 수. 다음 퀘스트는 항상 [claimed] + 1번이다.
class QuestState {
  const QuestState({this.claimed = 0});

  static const empty = QuestState();

  final int claimed;

  /// 지금 진행 중인 퀘스트. 60개를 다 받았으면 null.
  Quest? get current => claimed < questTable.length ? questTable[claimed] : null;

  QuestState claim() => QuestState(claimed: claimed + 1);

  Map<String, dynamic> toJson() => {'claimed': claimed};

  factory QuestState.fromJson(Map<String, dynamic> j) =>
      QuestState(claimed: (j['claimed'] as num? ?? 0).toInt());
}

/// 지금까지의 진행도. 목표치를 넘어도 그대로 돌려주므로 화면에서 잘라 쓴다.
int questProgress(Quest quest, GameState s) => switch (quest.goal) {
      QuestGoal.stage => s.highestStage,
      QuestGoal.totalKills => s.totalKills,
      QuestGoal.enhanceLevel => s.equipment.enhanceLevel,
      QuestGoal.dungeonFloors => s.dungeon.cleared.values.fold(0, (a, b) => a + b),
      QuestGoal.codexRegistered => s.codex.values.where((stars) => stars > 0).length,
    };

bool questReady(GameState s) {
  final quest = s.quests.current;
  return quest != null && questProgress(quest, s) >= quest.target;
}

/// 층 해금표. 다음 목표를 한 줄로 보여 주는 데 쓴다.
///
/// 방치형에서 "다음에 뭐가 열리는가"는 진행 자체보다 강한 유도다.
/// 던전 4종은 [DungeonType.unlockStage]와 같은 값이어야 한다.
const unlockTable = <(int, String)>[
  (10, '황금 동굴'),
  (20, '강화석 광산'),
  (30, '용의 둥지'),
  (50, '고대 유적'),
  (80, '펫 슬롯'),
  (100, '1차 전직'),
  (120, '스킬 슬롯 2'),
  (150, '2차 전직'),
  (200, '스킬 슬롯 3'),
  (300, '3차 전직'),
];

/// 아직 열리지 않은 것 중 가장 가까운 해금. 전부 열었으면 null.
(int, String)? nextUnlock(int highestStage) {
  for (final entry in unlockTable) {
    if (highestStage < entry.$1) return entry;
  }
  return null;
}

/// 퀘스트 보상을 상태에 넣는다. 재화마다 쌓이는 자리가 다르다.
GameState grantQuestReward(GameState s, Quest quest, BalanceConfig c) {
  final amount = quest.rewardAmount;
  return switch (quest.reward) {
    RewardKind.gold => s.copyWith(gold: s.gold + amount),
    RewardKind.stone =>
      s.copyWith(equipment: s.equipment.copyWith(stones: s.equipment.stones + amount)),
    RewardKind.ticket => s.copyWith(
        dungeon: s.dungeon.copyWith(
          tickets: (s.dungeon.tickets + amount).clamp(0, c.dungeonTicketCap),
        ),
      ),
    RewardKind.eggShard => s.copyWith(dungeon: s.dungeon.copyWith(eggShards: s.dungeon.eggShards + amount)),
    RewardKind.skillPage =>
      s.copyWith(dungeon: s.dungeon.copyWith(skillPages: s.dungeon.skillPages + amount)),
  };
}
