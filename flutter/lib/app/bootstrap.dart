import '../data/cloud_save_gateway.dart';
import '../data/save_repository.dart';
import '../domain/balance_config.dart';
import '../domain/game_state.dart';
import '../domain/offline_reward.dart';
import '../domain/save_codec.dart';

/// 앱 시작 시 세이브를 정하고 오프라인 보상을 반영한 초기 상태를 만든다.
///
/// 서버가 정본이다(GAME_DESIGN 12장): 서버가 닿으면 서버 세이브와 서버가 계산한 보상을 쓰고
/// 로컬에도 같은 것을 써 둔다. 서버가 안 닿으면 로컬 세이브 + 로컬 계산 보상으로 시작한다.
class Bootstrap {
  const Bootstrap({required this.state, required this.offlineReward, required this.fromCloud});

  final GameState state;

  /// 저장 데이터가 없거나 보상이 0이면 null.
  final OfflineReward? offlineReward;
  final bool fromCloud;

  static Future<Bootstrap> load({
    required SaveRepository local,
    required CloudSaveGateway? cloud,
    required BalanceConfig config,
    required DateTime now,
  }) async {
    if (cloud != null) {
      try {
        final remote = await cloud.load();
        await local.save(SaveData(state: remote.state, savedAt: now));
        return Bootstrap(state: remote.state, offlineReward: remote.offlineReward, fromCloud: true);
      } on Object {
        // 네트워크·서버 오류 — 아래 로컬 경로로.
      }
    }

    final save = await local.load();
    if (save == null) {
      return Bootstrap(state: GameState.initial(config), offlineReward: null, fromCloud: false);
    }
    final reward = OfflineReward.calculate(save.state, save.savedAt, now, config);
    return Bootstrap(
      state: save.state.copyWith(gold: save.state.gold + reward.gold),
      offlineReward: reward.gold > 0 ? reward : null,
      fromCloud: false,
    );
  }
}
