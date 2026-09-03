import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/app/game_controller.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/ui/codex_screen.dart';
import 'package:idle_fantasy/ui/sprites/monster_sprite.dart';

import '../support/catalog.dart';
import '../support/in_memory_save_repository.dart';

void main() {
  testWidgets('지역별 그리드에 전 몬스터가 나오고 미등록은 ???, 등록은 이름과 별', (tester) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          monsterCatalogProvider.overrideWithValue(smallCatalog),
          initialStateProvider.overrideWithValue(
            GameState.initial(const BalanceConfig()).copyWith(codex: const {1: 3}),
          ),
        ],
        child: const MaterialApp(home: CodexScreen()),
      ),
    );

    expect(find.textContaining('도감  1/4'), findsOneWidget);
    expect(find.byType(MonsterSprite), findsNWidgets(4));
    expect(find.text('슬라임'), findsOneWidget);
    expect(find.text('???'), findsNWidgets(3));
    expect(find.text('★★★☆☆'), findsOneWidget);
    expect(find.textContaining('숲  1~10층  1/2'), findsOneWidget);

    await tester.tap(find.text('슬라임'));
    await tester.pumpAndSettle();
    expect(find.textContaining('골드 획득 +1.5%'), findsOneWidget);
  });
}
