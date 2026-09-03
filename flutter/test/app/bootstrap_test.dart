import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/app/bootstrap.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

import '../support/in_memory_save_repository.dart';

void main() {
  const c = BalanceConfig();
  final now = DateTime(2026, 9, 3, 12);

  test('저장이 없으면 새 게임, 보상 없음', () async {
    final boot = await Bootstrap.load(InMemorySaveRepository(), c, now);
    expect(boot.state.stage, 1);
    expect(boot.state.gold, 0);
    expect(boot.offlineReward, isNull);
  });

  test('저장이 있으면 복원하고 오프라인 골드를 더한다', () async {
    final saved = GameState.initial(c).copyWith(stage: 4, highestStage: 6, gold: 100);
    final repo = InMemorySaveRepository(
      SaveData(state: saved, savedAt: now.subtract(const Duration(hours: 2))),
    );
    final boot = await Bootstrap.load(repo, c, now);
    expect(boot.state.stage, 4);
    expect(boot.state.highestStage, 6);
    expect(boot.offlineReward, isNotNull);
    expect(boot.state.gold, closeTo(100 + boot.offlineReward!.gold, 1e-9));
    expect(boot.offlineReward!.gold, greaterThan(0));
  });

  test('방금 저장한 거면 복원만 하고 팝업(보상)은 없다', () async {
    final saved = GameState.initial(c).copyWith(gold: 50);
    final repo = InMemorySaveRepository(
      SaveData(state: saved, savedAt: now.subtract(const Duration(seconds: 10))),
    );
    final boot = await Bootstrap.load(repo, c, now);
    expect(boot.state.gold, 50);
    expect(boot.offlineReward, isNull);
  });
}
