import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/summon.dart';
import 'package:idle_fantasy/ui/hud/pixel_ui.dart';
import 'package:idle_fantasy/ui/hud/summon_flourish.dart';

void main() {
  group('기둥 색', () {
    test('굴린 성급이 색을 정한다 — 흰 · 파랑 · 보라 · 금', () {
      expect(pillarColorFor(1), PixelPalette.text);
      expect(pillarColorFor(2), PixelPalette.text);
      expect(pillarColorFor(3), PixelPalette.gem);
      expect(pillarColorFor(4), const Color(0xFFB388FF));
      expect(pillarColorFor(5), PixelPalette.gold);
    });

    test('범위를 벗어나도 안 터진다', () {
      expect(pillarColorFor(0), PixelPalette.text);
      expect(pillarColorFor(99), PixelPalette.gold);
    });
  });

  group('연출', () {
    Future<void> open(WidgetTester tester, List<SummonResult> results) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSummonFlourish(context, results),
            child: const Text('열기'),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pump();
    }

    testWidgets('끝까지 두면 결과가 뜬다', (tester) async {
      await open(tester, const [
        SummonResult(slot: RelicSlot.horn, stars: 5, byPity: false, before: 0, after: 5),
      ]);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.text('뿔 ★5'), findsWidgets);
      expect(find.text('빈 곳을 터치하세요'), findsWidgets);
    });

    testWidgets('탭하면 건너뛰고 결과로 간다', (tester) async {
      await open(tester, const [
        SummonResult(slot: RelicSlot.wing, stars: 1, byPity: false, before: 4, after: 5),
      ]);
      // 아직 연출 중이라 결과가 없다.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('날개 ★4 → ★5'), findsNothing);

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(find.text('날개 ★4 → ★5'), findsWidgets, reason: '건너뛰면 즉시 결과다');
    });

    testWidgets('10연차는 기둥 하나에 결과 열 줄이다', (tester) async {
      final results = [
        for (var i = 0; i < 10; i++)
          SummonResult(
            slot: RelicSlot.values[i % 4],
            stars: i == 3 ? 5 : 1,
            byPity: false,
            before: 0,
            after: i == 3 ? 5 : 1,
          ),
      ];
      await open(tester, results);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.byType(SummonResultLine), findsNWidgets(10));
    });

    testWidgets('기둥 색은 굴린 값 중 최고를 따른다', (tester) async {
      final results = [
        const SummonResult(slot: RelicSlot.horn, stars: 1, byPity: false, before: 0, after: 1),
        const SummonResult(slot: RelicSlot.tail, stars: 5, byPity: false, before: 0, after: 5),
      ];
      await open(tester, results);
      // 기둥 구간은 t=0.45부터다. 1600ms × 0.45 = 720ms — 600ms에는 아직 위젯이 없다.
      await tester.pump(const Duration(milliseconds: 800));
      final pillar = tester.widget<SummonPillar>(find.byType(SummonPillar));
      expect(pillar.color, PixelPalette.gold);
    });
  });
}
