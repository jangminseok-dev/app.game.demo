import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/spirit.dart';
import 'package:idle_fantasy/ui/hud/spirit_cutscene.dart';

void main() {
  Future<void> open(WidgetTester tester, SpiritId id) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSpiritCutscene(context, id),
          child: const Text('열기'),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump();
  }

  testWidgets('정령 이름이 뜬다', (tester) async {
    await open(tester, SpiritId.frost);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('서리의 꿈'), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('1.5초 안에 스스로 닫힌다 — 건너뛸 수 없다', (tester) async {
    await open(tester, SpiritId.moss);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(SpiritGlow), findsOneWidget);

    // 탭해도 안 닫힌다.
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(find.byType(SpiritGlow), findsOneWidget, reason: '건너뛸 수 없다(스펙 7.3)');

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.byType(SpiritGlow), findsNothing, reason: '스스로 닫힌다');
  });

  testWidgets('위에 다른 팝업이 쌓여도 컷신은 자기 것만 닫는다', (tester) async {
    await open(tester, SpiritId.moss);
    await tester.pump(const Duration(milliseconds: 200));

    // 컷신이 떠 있는 동안 다른 다이얼로그를 얹는다.
    final ctx = tester.element(find.byType(SpiritGlow));
    unawaited(showDialog<void>(
      context: ctx,
      builder: (_) => const Material(child: Text('다른 팝업')),
    ));
    await tester.pump();
    expect(find.text('다른 팝업'), findsWidgets);

    // 컷신이 스스로 끝난다.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.byType(SpiritGlow), findsNothing, reason: '컷신은 닫혔다');
    expect(find.text('다른 팝업'), findsWidgets, reason: '남의 팝업을 대신 닫으면 안 된다');
  });

  testWidgets('뒤로 가기로도 안 닫힌다', (tester) async {
    await open(tester, SpiritId.crystal);
    await tester.pump(const Duration(milliseconds: 400));
    final popped = await tester.binding.handlePopRoute();
    expect(popped, isTrue, reason: '시스템이 처리는 한다');
    // 라우트 퇴장은 여러 프레임에 걸쳐 반영된다. 한 번에 시계를 점프시키면
    // 오버레이 정리가 그 프레임에 안 잡혀서 막았을 때와 구분이 안 된다.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(find.byType(SpiritGlow), findsOneWidget, reason: '컷신은 남아 있어야 한다');
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  });

  testWidgets('정령마다 색이 다르다', (tester) async {
    for (final id in [SpiritId.moss, SpiritId.crystal]) {
      await open(tester, id);
      await tester.pump(const Duration(milliseconds: 400));
      final glow = tester.widget<SpiritGlow>(find.byType(SpiritGlow));
      expect(glow.color, Color(id.color), reason: id.label);
      await tester.pumpAndSettle();
    }
  });
}
