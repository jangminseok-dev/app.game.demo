import '../domain/codex.dart';
import '../domain/game_state.dart';
import '../domain/offline_reward.dart';
import '../domain/save_codec.dart';
import 'idle_api_client.dart';

/// 서버 세이브 포트. 서버가 정본이다 — 시작 시 [load]로 받고, 진행 중 [sync]로 올린다.
abstract class CloudSaveGateway {
  Future<CloudLoad> load();

  /// 델타 검증 실패면 `accepted == false`와 함께 서버 상태를 돌려준다. 클라이언트는 그 상태로 롤백한다.
  /// 수락되면 [CloudSync.captures]에 이번 처치 보고로 굴린 포획 결과가 실린다.
  Future<CloudSync> sync(GameState state);
}

class CloudLoad {
  const CloudLoad({required this.state, required this.offlineReward, required this.codex});
  final GameState state;
  final OfflineReward? offlineReward;
  final Map<int, int> codex;
}

class CloudSync {
  const CloudSync({
    required this.accepted,
    required this.state,
    required this.rejectedRule,
    this.captures = const [],
  });
  final bool accepted;
  final GameState state;
  final String? rejectedRule;
  final List<CaptureEvent> captures;
}

/// 서버 세이브 형식이 깨졌을 때. 로컬 경로로 폴백한다.
class CorruptRemoteSave implements Exception {}

class ApiCloudSaveGateway implements CloudSaveGateway {
  ApiCloudSaveGateway(this._api, this._session);

  final IdleApiClient _api;
  final GuestSession _session;

  @override
  Future<CloudLoad> load() async {
    final r = await _api.load(_session);
    final state = decodeState(r.state);
    if (state == null) throw CorruptRemoteSave();
    return CloudLoad(state: state, offlineReward: r.offlineReward, codex: r.codex);
  }

  @override
  Future<CloudSync> sync(GameState state) async {
    final r = await _api.sync(_session, encodeState(state));
    final server = decodeState(r.state);
    if (server == null) throw CorruptRemoteSave();
    return CloudSync(accepted: r.accepted, state: server, rejectedRule: r.rejectedRule, captures: r.captures);
  }
}
