import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/app/game_controller.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/codex.dart';
import 'package:idle_fantasy/domain/game_state.dart';

import '../support/catalog.dart';
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
        monsterCatalogProvider.overrideWithValue(smallCatalog),
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

  test('수락되면 보낸 처치 보고를 빼고 포획을 도감에 반영하고 피드에 올린다', () async {
    final cloud = FakeCloudSaveGateway()
      ..captures = const [CaptureEvent(monsterId: 1, stars: 1, first: true)];
    final container = make(
      repo: InMemorySaveRepository(),
      cloud: cloud,
      initial: GameState.initial(c).copyWith(killLog: const {1: 4}, bossKillLog: const {1: 1}),
    );

    await container.read(gameControllerProvider.notifier).saveNow();

    final s = container.read(gameControllerProvider);
    expect(cloud.synced.single.killLog, {1: 4});
    expect(s.killLog, isEmpty, reason: '보낸 만큼 소비');
    expect(s.bossKillLog, isEmpty);
    expect(s.codex, {1: 1});
    expect(s.passives.gold, closeTo(0.5, 1e-9));
    expect(container.read(captureFeedProvider).single.monsterId, 1);
    container.read(captureFeedProvider.notifier).clear();
    expect(container.read(captureFeedProvider), isEmpty);
  });

  test('거부되면 도감은 유지한 채 서버 상태로 롤백한다', () async {
    final cloud = FakeCloudSaveGateway(rejectWith: 'gold_conservation')
      ..rejectedState = GameState.initial(c).copyWith(gold: 30);
    final container = make(
      repo: InMemorySaveRepository(),
      cloud: cloud,
      initial: GameState.initial(c).copyWith(gold: 999, codex: const {3: 2}, killLog: const {1: 2}),
    );

    await container.read(gameControllerProvider.notifier).saveNow();

    final s = container.read(gameControllerProvider);
    expect(s.gold, 30);
    expect(s.codex, {3: 2});
    expect(s.passives.crit, closeTo(0.4, 1e-9));
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
