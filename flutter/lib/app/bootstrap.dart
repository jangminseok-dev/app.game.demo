import '../data/cloud_save_gateway.dart';
import '../data/save_repository.dart';
import '../domain/balance_config.dart';
import '../domain/battle_engine.dart';
import '../domain/game_state.dart';
import '../domain/monster.dart';
import '../domain/offline_reward.dart';
import '../domain/save_codec.dart';

/// 앱 시작 시 세이브를 정하고 오프라인 보상을 반영한 초기 상태를 만든다.
///
/// 서버가 정본이다(GAME_DESIGN 12장): 서버가 닿으면 서버 세이브·도감과 서버가 계산한 보상을 쓰고
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
    MonsterCatalog catalog = MonsterCatalog.empty,
  }) async {
    final engine = BattleEngine(config, catalog: catalog);

    if (cloud != null) {
      try {
        final remote = await cloud.load();
        final state = engine.withCodex(remote.state, remote.codex, pity: remote.pity);
        await local.save(SaveData(state: state, savedAt: now));
        return Bootstrap(state: state, offlineReward: remote.offlineReward, fromCloud: true);
      } on Object {
        // 네트워크·서버 오류 — 아래 로컬 경로로.
      }
    }

    final save = await local.load();
    if (save == null) {
      return Bootstrap(state: GameState.initial(config), offlineReward: null, fromCloud: false);
    }
    // 로컬 세이브의 도감으로 패시브를 다시 계산한다(카탈로그가 바뀌었을 수 있다).
    final restored = engine.withCodex(save.state, save.state.codex);
    final reward = OfflineReward.calculate(restored, save.savedAt, now, config);
    // 입장권은 오프라인 상한과 무관하게 실제 경과 시간만큼 찬다 — 며칠 쉬어도 손해가 없어야 한다.
    final away = now.difference(save.savedAt).inSeconds.toDouble();
    return Bootstrap(
      state: restored.copyWith(
        gold: restored.gold + reward.gold,
        dungeon: restored.dungeon.regenerate(away > 0 ? away : 0, config),
        hatchery: restored.hatchery.advance(away > 0 ? away : 0),
      ),
      offlineReward: reward.gold > 0 ? reward : null,
      fromCloud: false,
    );
  }
}
