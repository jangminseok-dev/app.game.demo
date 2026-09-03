import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/game_screen.dart';

void main() {
  testWidgets('화면이 뜨고 시간이 흐르면 골드가 생긴다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameScreen())),
    );
    expect(find.textContaining('스테이지 1'), findsOneWidget);
    expect(find.text('골드  0'), findsOneWidget);
    for (final label in ['공격력', '공격속도', '치명타', '골드획득', '포획률']) {
      expect(find.textContaining(label), findsOneWidget);
    }

    // 3초 진행: 스테이지 1 몬스터(HP 11.8)는 공격 10으로 2회면 죽는다.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('골드  0'), findsNothing);
  });
}
