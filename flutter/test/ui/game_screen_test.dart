import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/app/game_controller.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/offline_reward.dart';
import 'package:idle_fantasy/ui/battle_area.dart';
import 'package:idle_fantasy/ui/game_screen.dart';
import 'package:idle_fantasy/ui/hud/game_popup.dart';

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
    // 가로 화면 (2026-09-05 가로 전환)
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    expect(find.textContaining('1층'), findsWidgets);
    expect(find.byType(BattleArea), findsOneWidget);
    expect(find.text('몬스터'), findsWidgets, reason: '카탈로그가 비어 있으면 일반 이름 (외곽선 글자라 stroke·fill 2개)');
    // 하단 5칸 + 우상단 4칸 + 좌측 아래 2칸. 잠긴 것도 자리는 있다.
    for (final label in ['장비', '스킬', '대장간', '무기', '성장', '콘텐츠', '소환', '상점', '메뉴', '출석', '오늘']) {
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

    // 성장 팝업을 닫아야 우하단 AUTO 단추를 누를 수 있다.
    await tester.tap(find.text('X').first);
    await tester.pumpAndSettle();

    // AUTO 단추는 슬롯 셋의 자동을 한 번에 끈다.
    final container = ProviderScope.containerOf(tester.element(find.byType(BattleArea)));
    await tester.tap(find.text('AUTO').first);
    await tester.pump();
    final skills = container.read(gameControllerProvider).skills;
    expect([0, 1, 2].map(skills.isAuto), everyElement(isFalse), reason: 'AUTO를 끄면 셋 다 꺼진다');
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
    expect(find.textContaining('+1500'), findsWidgets);

    await tester.tap(find.widgetWithText(GestureDetector, 'X').first);
    await tester.pumpAndSettle();
    expect(find.text('오프라인 보상'), findsNothing);
  });

  testWidgets('보스가 나오면 경고 띠가 뜬다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    expect(find.textContaining('WARNING'), findsNothing);

    // 보스가 나올 때까지 돌린다.
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('WARNING').evaluate().isNotEmpty) break;
    }
    expect(find.textContaining('WARNING'), findsWidgets, reason: '보스 등장 경고');
    expect(tester.takeException(), isNull);
  });

  testWidgets('퀘스트 보상을 받으면 획득 창이 뜬다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const config = BalanceConfig();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          offlineRewardProvider.overrideWithValue(null),
          // 1번 퀘스트(10마리 처치)를 이미 채운 상태로 시작한다.
          initialStateProvider.overrideWithValue(
            GameState.initial(config).copyWith(totalKills: 50),
          ),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('받기'), findsWidgets, reason: '받을 수 있는 퀘스트');
    await tester.tap(find.widgetWithText(GestureDetector, '받기').first);
    await tester.pumpAndSettle();
    expect(find.text('보상'), findsWidgets);
    expect(find.textContaining('빈 곳을 터치'), findsWidgets);

    // 빈 곳을 누르면 닫힌다.
    await tester.tapAt(const Offset(30, 30));
    await tester.pumpAndSettle();
    expect(find.text('보상'), findsNothing);
  });

  testWidgets('메뉴 그리드가 열리고 콘텐츠에 던전·층 이동이 있다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('메뉴').first);
    await tester.pumpAndSettle();
    for (final label in ['캐릭터', '강화', '영지', '동료', '랭킹', '도움말', '설정']) {
      expect(find.text(label), findsWidgets, reason: '$label 칸 (잠금이라도 자리는 있다)');
    }
    expect(find.textContaining('도감'), findsWidgets);

    // 메뉴 그리드가 열린 뒤라 화면에 '콘텐츠'가 둘이다 — 뒤쪽(원래 우상단 단추)은 바리어에 가려 눌리지 않는다. 그리드 칸(뒤 항목)을 누른다.
    await tester.tap(find.text('콘텐츠').last);
    await tester.pumpAndSettle();
    expect(find.text('던전'), findsWidgets);
    expect(find.text('도전'), findsWidgets);
    expect(find.text('층 이동'), findsWidgets, reason: '층 이동이 던전 탭 안에 있다');
  });

  testWidgets('잠금 단추는 화면을 열지 않고 준비 중만 알린다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('소환').first);
    await tester.pump();
    expect(find.textContaining('준비 중'), findsWidgets);
    expect(find.byType(GamePopup), findsNothing, reason: '잠금 단추는 팝업을 열지 않는다');
  });
}
