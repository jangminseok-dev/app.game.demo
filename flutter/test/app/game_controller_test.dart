import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/app/game_controller.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';

import '../support/fake_cloud_save_gateway.dart';
import '../support/in_memory_save_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const c = BalanceConfig();

  ProviderContainer make({
    required InMemorySaveRepository repo,
    FakeCloudSaveGateway? cloud,
    GameState? initial,
  }) {
    final container = ProviderContainer(
      overrides: [
        saveRepositoryProvider.overrideWithValue(repo),
        cloudSaveProvider.overrideWithValue(cloud),
        if (initial != null) initialStateProvider.overrideWithValue(initial),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('saveNow는 현재 상태를 로컬에 쓰고 저장 시각을 남긴다', () async {
    final repo = InMemorySaveRepository();
    final container = make(repo: repo, initial: GameState.initial(c).copyWith(stage: 9, gold: 77));

    expect(container.read(gameControllerProvider).stage, 9);
    expect(container.read(saveStatusProvider).lastSavedAt, isNull);

    await container.read(gameControllerProvider.notifier).saveNow();

    expect(repo.saveCount, 1);
    expect(repo.stored!.state.stage, 9);
    expect(container.read(saveStatusProvider).lastSavedAt, isNotNull);
    expect(container.read(saveStatusProvider).lastSyncedAt, isNull, reason: '서버 없음');
  });

  test('서버가 있으면 동기화하고 시각을 남긴다', () async {
    final cloud = FakeCloudSaveGateway();
    final container = make(repo: InMemorySaveRepository(), cloud: cloud);

    await container.read(gameControllerProvider.notifier).saveNow();

    expect(cloud.synced.length, 1);
    expect(container.read(saveStatusProvider).lastSyncedAt, isNotNull);
  });

  test('서버가 거부하면 서버 상태로 롤백하고 규칙을 남긴다', () async {
    final serverState = GameState.initial(c).copyWith(gold: 30);
    final cloud = FakeCloudSaveGateway(rejectWith: 'gold_conservation')..rejectedState = serverState;
    final container = make(
      repo: InMemorySaveRepository(),
      cloud: cloud,
      initial: GameState.initial(c).copyWith(gold: 999999),
    );

    await container.read(gameControllerProvider.notifier).saveNow();

    expect(container.read(gameControllerProvider).gold, 30);
    expect(container.read(saveStatusProvider).lastRejectedRule, 'gold_conservation');
    expect(container.read(saveStatusProvider).lastSyncedAt, isNull);
  });

  test('서버 오류는 삼키고 로컬 저장은 유지된다', () async {
    final repo = InMemorySaveRepository();
    final cloud = FakeCloudSaveGateway()..syncError = Exception('offline');
    final container = make(repo: repo, cloud: cloud);

    await container.read(gameControllerProvider.notifier).saveNow();

    expect(repo.saveCount, 1);
    expect(container.read(saveStatusProvider).lastSyncedAt, isNull);
  });

  test('30초마다 자동 저장된다', () {
    fakeAsync((async) {
      final repo = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repo)],
      );
      container.read(gameControllerProvider);

      async.elapse(const Duration(seconds: 29));
      expect(repo.saveCount, 0);
      async.elapse(const Duration(seconds: 2));
      expect(repo.saveCount, 1);
      async.elapse(const Duration(seconds: 30));
      expect(repo.saveCount, 2);

      container.dispose();
    });
  });
}
