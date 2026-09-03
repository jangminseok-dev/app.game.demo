import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/app/game_controller.dart';
import 'package:idle_fantasy/domain/offline_reward.dart';
import 'package:idle_fantasy/ui/game_screen.dart';

import '../support/in_memory_save_repository.dart';

void main() {
  Widget app({OfflineReward? reward}) => ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          offlineRewardProvider.overrideWithValue(reward),
        ],
        child: const MaterialApp(home: GameScreen()),
      );

  testWidgets('화면이 뜨고 시간이 흐르면 골드가 생긴다', (tester) async {
    await tester.pumpWidget(app());
    expect(find.textContaining('스테이지 1'), findsOneWidget);
    expect(find.text('골드  0'), findsOneWidget);
    expect(find.textContaining('저장 전'), findsOneWidget);
    for (final label in ['공격력', '공격속도', '치명타', '골드획득', '포획률']) {
      expect(find.textContaining(label), findsOneWidget);
    }

    // 3초 진행: 스테이지 1 몬스터(HP 11.8)는 공격 10으로 2회면 죽는다.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('골드  0'), findsNothing);
  });

  testWidgets('오프라인 보상이 있으면 팝업이 한 번 뜬다', (tester) async {
    await tester.pumpWidget(app(
      reward: const OfflineReward(elapsed: Duration(hours: 2, minutes: 5), gold: 1500),
    ));
    await tester.pump();
    expect(find.text('오프라인 보상'), findsOneWidget);
    expect(find.textContaining('2시간 5분'), findsOneWidget);
    expect(find.textContaining('+1.50K'), findsOneWidget);

    await tester.tap(find.text('받기'));
    await tester.pump();
    expect(find.text('오프라인 보상'), findsNothing);
  });
}
