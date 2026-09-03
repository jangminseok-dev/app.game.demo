import 'package:idle_fantasy/data/cloud_save_gateway.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/offline_reward.dart';

/// 테스트용 서버 세이브. 응답을 미리 정해 두고 호출을 기록한다.
class FakeCloudSaveGateway implements CloudSaveGateway {
  FakeCloudSaveGateway({this.loadResult, this.loadError, this.rejectWith});

  CloudLoad? loadResult;
  Object? loadError;

  /// null이면 수락, 값이 있으면 그 규칙으로 거부하고 [rejectedState]를 돌려준다.
  String? rejectWith;
  GameState? rejectedState;
  Object? syncError;

  final synced = <GameState>[];

  @override
  Future<CloudLoad> load() async {
    if (loadError != null) throw loadError!;
    return loadResult!;
  }

  @override
  Future<CloudSync> sync(GameState state) async {
    if (syncError != null) throw syncError!;
    synced.add(state);
    if (rejectWith != null) {
      return CloudSync(accepted: false, state: rejectedState!, rejectedRule: rejectWith);
    }
    return CloudSync(accepted: true, state: state, rejectedRule: null);
  }
}

CloudLoad cloudLoad(GameState s, {OfflineReward? reward}) => CloudLoad(state: s, offlineReward: reward);
