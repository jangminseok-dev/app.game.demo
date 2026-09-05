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
