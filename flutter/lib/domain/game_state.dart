import 'balance_config.dart';
import 'formulas.dart' as formulas;
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

  Stats get stats => Stats.fromLevels(levels);

  int levelOf(UpgradeType type) => levels[type] ?? 0;

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
    );
  }
}
