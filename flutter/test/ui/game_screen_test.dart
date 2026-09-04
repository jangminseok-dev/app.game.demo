import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/app/game_controller.dart';
import 'package:idle_fantasy/domain/offline_reward.dart';
import 'package:idle_fantasy/ui/battle_area.dart';
import 'package:idle_fantasy/ui/game_screen.dart';

import '../support/catalog.dart';
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
    // 전투 무대 아래 목록까지 한 화면에 보이도록 세로로 길게 (실기기 세로 화면 비율)
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    expect(find.textContaining('스테이지 1'), findsWidgets);
    expect(find.byType(BattleArea), findsOneWidget);
    expect(find.text('몬스터'), findsWidgets, reason: '카탈로그가 비어 있으면 일반 이름 (외곽선 글자라 stroke·fill 2개)');
    // 기능은 전부 전투 위 단추다.
    for (final label in ['성장', '장비', '펫', '퀘스트', '던전']) {
      expect(find.text(label), findsWidgets, reason: '$label 단추');
    }

    // 3초 진행: 스테이지 1 몬스터(HP 11.8)는 공격 10으로 2회면 죽는다.
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull, reason: '피격·등장 연출이 예외 없이 돈다');

    // 성장 단추를 누르면 팝업이 뜨고 골드가 쌓여 있다.
    await tester.tap(find.text('성장').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('골드'), findsWidgets);
    expect(find.text('골드  0'), findsNothing, reason: '3초 동안 골드가 생겼다');
    for (final label in ['공격력', '공격속도', '치명타', '골드획득', '포획률']) {
      expect(find.textContaining(label), findsWidgets);
    }
    expect(find.textContaining('저장 전'), findsWidgets);
  });

  testWidgets('카탈로그가 있으면 전투 무대에 몬스터 이름·속성·지역이 나온다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          monsterCatalogProvider.overrideWithValue(smallCatalog),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    expect(find.text('슬라임 [무]'), findsWidgets);
    expect(find.textContaining('숲'), findsWidgets);
    expect(find.textContaining('미등록 ·'), findsWidgets);
  });

  testWidgets('오프라인 보상이 있으면 팝업이 한 번 뜬다', (tester) async {
    await tester.pumpWidget(app(
      reward: const OfflineReward(elapsed: Duration(hours: 2, minutes: 5), gold: 1500),
    ));
    await tester.pump();
    expect(find.text('오프라인 보상'), findsWidgets);
    expect(find.textContaining('2시간 5분'), findsWidgets);
    expect(find.textContaining('+1.50K'), findsWidgets);

    await tester.tap(find.widgetWithText(GestureDetector, 'X').first);
    await tester.pumpAndSettle();
    expect(find.text('오프라인 보상'), findsNothing);
  });
}
