import '../data/save_repository.dart';
import '../domain/balance_config.dart';
import '../domain/game_state.dart';
import '../domain/offline_reward.dart';

/// 앱 시작 시 저장 데이터를 읽고 오프라인 보상을 반영한 초기 상태를 만든다.
class Bootstrap {
  const Bootstrap({required this.state, required this.offlineReward});

  final GameState state;

  /// 저장 데이터가 없거나 보상이 0이면 null.
  final OfflineReward? offlineReward;

  static Future<Bootstrap> load(
    SaveRepository repo,
    BalanceConfig config,
    DateTime now,
  ) async {
    final save = await repo.load();
    if (save == null) {
      return Bootstrap(state: GameState.initial(config), offlineReward: null);
    }
    final reward = OfflineReward.calculate(save.state, save.savedAt, now, config);
    return Bootstrap(
      state: save.state.copyWith(gold: save.state.gold + reward.gold),
      offlineReward: reward.gold > 0 ? reward : null,
    );
  }
}
