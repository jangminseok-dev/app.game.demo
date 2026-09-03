import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/app/bootstrap.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/offline_reward.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

import '../support/catalog.dart';
import '../support/fake_cloud_save_gateway.dart';
import '../support/in_memory_save_repository.dart';

void main() {
  const c = BalanceConfig();
  final now = DateTime(2026, 9, 3, 12);

  group('서버 없이 (로컬 경로)', () {
    test('저장이 없으면 새 게임, 보상 없음', () async {
      final boot = await Bootstrap.load(local: InMemorySaveRepository(), cloud: null, config: c, now: now);
      expect(boot.state.stage, 1);
      expect(boot.state.gold, 0);
      expect(boot.offlineReward, isNull);
      expect(boot.fromCloud, false);
    });

    test('저장이 있으면 복원하고 로컬 계산 오프라인 골드를 더한다', () async {
      final saved = GameState.initial(c).copyWith(stage: 4, highestStage: 6, gold: 100);
      final repo = InMemorySaveRepository(
        SaveData(state: saved, savedAt: now.subtract(const Duration(hours: 2))),
      );
      final boot = await Bootstrap.load(local: repo, cloud: null, config: c, now: now);
      expect(boot.state.stage, 4);
      expect(boot.offlineReward, isNotNull);
      expect(boot.state.gold, closeTo(100 + boot.offlineReward!.gold, 1e-9));
    });

    test('방금 저장한 거면 복원만 하고 팝업(보상)은 없다', () async {
      final repo = InMemorySaveRepository(
        SaveData(state: GameState.initial(c).copyWith(gold: 50), savedAt: now.subtract(const Duration(seconds: 10))),
      );
      final boot = await Bootstrap.load(local: repo, cloud: null, config: c, now: now);
      expect(boot.state.gold, 50);
      expect(boot.offlineReward, isNull);
    });
  });

  group('서버 연결 (서버가 정본)', () {
    test('서버 세이브와 서버가 계산한 보상을 쓰고 로컬에도 써 둔다', () async {
      final localOld = GameState.initial(c).copyWith(stage: 2, gold: 999);
      final repo = InMemorySaveRepository(SaveData(state: localOld, savedAt: now));
      final server = GameState.initial(c).copyWith(stage: 7, highestStage: 7, gold: 300);
      const reward = OfflineReward(elapsed: Duration(hours: 1), gold: 120);
      final cloud = FakeCloudSaveGateway(loadResult: cloudLoad(server, reward: reward));

      final boot = await Bootstrap.load(local: repo, cloud: cloud, config: c, now: now);

      expect(boot.fromCloud, true);
      expect(boot.state.stage, 7);
      expect(boot.state.gold, 300, reason: '보상은 서버가 이미 상태에 더해서 준다');
      expect(boot.offlineReward, same(reward));
      expect(repo.stored!.state.stage, 7, reason: '로컬 캐시가 서버 값으로 바뀐다');
      expect(repo.stored!.savedAt, now);
    });

    test('서버 도감을 상태에 싣고 패시브를 계산한다', () async {
      final repo = InMemorySaveRepository();
      final cloud = FakeCloudSaveGateway(loadResult: cloudLoad(GameState.initial(c), codex: {1: 2, 2: 1}));

      final boot = await Bootstrap.load(local: repo, cloud: cloud, config: c, now: now, catalog: smallCatalog);

      expect(boot.state.codex, {1: 2, 2: 1});
      expect(boot.state.passives.attack, 20, reason: '숲 완성');
      expect(repo.stored!.state.codex, {1: 2, 2: 1}, reason: '로컬 캐시에도 도감이 남는다');
    });

    test('로컬 폴백 시 저장된 도감으로 패시브를 다시 계산한다', () async {
      final repo = InMemorySaveRepository(
        SaveData(state: GameState.initial(c).copyWith(codex: const {3: 2}), savedAt: now),
      );
      final boot = await Bootstrap.load(local: repo, cloud: null, config: c, now: now, catalog: smallCatalog);
      expect(boot.state.passives.crit, closeTo(0.4, 1e-9));
    });

    test('서버 호출이 실패하면 로컬 경로로 폴백한다', () async {
      final repo = InMemorySaveRepository(
        SaveData(state: GameState.initial(c).copyWith(stage: 3), savedAt: now.subtract(const Duration(hours: 1))),
      );
      final cloud = FakeCloudSaveGateway(loadError: Exception('offline'));

      final boot = await Bootstrap.load(local: repo, cloud: cloud, config: c, now: now);

      expect(boot.fromCloud, false);
      expect(boot.state.stage, 3);
      expect(boot.offlineReward, isNotNull, reason: '로컬 계산 보상');
    });
  });
}
