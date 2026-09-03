import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/app/game_controller.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';

import '../support/in_memory_save_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saveNow는 현재 상태를 저장소에 쓰고 저장 시각을 남긴다', () async {
    final repo = InMemorySaveRepository();
    final initial = GameState.initial(const BalanceConfig()).copyWith(stage: 9, gold: 77);
    final container = ProviderContainer(
      overrides: [
        saveRepositoryProvider.overrideWithValue(repo),
        initialStateProvider.overrideWithValue(initial),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(gameControllerProvider).stage, 9);
    expect(container.read(lastSavedAtProvider), isNull);

    await container.read(gameControllerProvider.notifier).saveNow();

    expect(repo.saveCount, 1);
    expect(repo.stored!.state.stage, 9);
    expect(repo.stored!.state.gold, 77);
    expect(container.read(lastSavedAtProvider), isNotNull);
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
