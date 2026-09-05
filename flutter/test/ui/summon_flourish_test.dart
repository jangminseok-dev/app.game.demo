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
      expect(find.byType(SummonPillar), findsOneWidget, reason: '10연차도 기둥은 하나다');
    });

    testWidgets('기둥 색은 굴린 값 중 최고를 따른다', (tester) async {
      final results = [
        const SummonResult(slot: RelicSlot.horn, stars: 1, byPity: false, before: 0, after: 1),
        const SummonResult(slot: RelicSlot.tail, stars: 5, byPity: false, before: 0, after: 5),
      ];
      await open(tester, results);
      // 기둥 구간은 t=0.45부터다. 1600ms × 0.45 = 720ms — 800ms에는 이미 기둥이 있다.
      await tester.pump(const Duration(milliseconds: 800));
      final pillar = tester.widget<SummonPillar>(find.byType(SummonPillar));
      expect(pillar.color, PixelPalette.gold);
    });

    testWidgets('결과가 보이면 탭이 바로 닫는다 — 건너뛸 것이 없다', (tester) async {
      await open(tester, const [
        SummonResult(slot: RelicSlot.horn, stars: 5, byPity: false, before: 0, after: 5),
      ]);
      // 1280ms부터 결과가 보인다. 그 뒤 아직 애니메이션이 안 끝난 시점을 고른다.
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('빈 곳을 터치하세요'), findsWidgets);

      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      expect(find.text('빈 곳을 터치하세요'), findsNothing, reason: '한 번 탭으로 닫혀야 한다');
    });

    testWidgets('기둥 바닥이 소환진 중심에 붙어 있다 — 화면이 커져도', (tester) async {
      for (final size in const [Size(844, 390), Size(1600, 720)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await open(tester, const [
          SummonResult(slot: RelicSlot.horn, stars: 5, byPity: false, before: 0, after: 5),
        ]);
        await tester.pump(const Duration(milliseconds: 800));
        final pillar = tester.getRect(find.byType(SummonPillar));
        final circle = tester.getRect(find.byType(SummonCircle));
        expect((pillar.bottom - circle.center.dy).abs(), lessThan(8),
            reason: '$size 에서 기둥이 소환진에서 떨어졌다');
        // 다음 반복이 새 화면에서 열 수 있게 이번 연출을 닫는다 —
        // 안 닫으면 같은 Navigator에 남은 이 연출이 다음 open()의 탭을 먹는다.
        await tester.pump(const Duration(milliseconds: 900));
        await tester.tapAt(Offset(size.width / 2, size.height / 2));
        await tester.pumpAndSettle();
      }
    });
  });

  group('세기', () {
    test('등급이 셀수록 파티클이 많고 섬광이 밝다', () {
      final weak = flourishForce(1);
      final mid = flourishForce(3);
      final top = flourishForce(5);
      expect(weak.sparks, lessThan(mid.sparks));
      expect(mid.sparks, lessThan(top.sparks));
      expect(weak.flash, lessThan(mid.flash));
      expect(mid.flash, lessThan(top.flash));
      expect(top.flash, 1.0);
    });

    test('범위를 벗어나도 안 터진다', () {
      expect(flourishForce(0).sparks, greaterThan(0));
      expect(flourishForce(99).sparks, flourishForce(5).sparks);
    });
  });

  testWidgets('★5는 ★1보다 파티클이 많다', (tester) async {
    Future<int> sparksFor(int stars) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSummonFlourish(context, [
              SummonResult(slot: RelicSlot.horn, stars: stars, byPity: false, before: 0, after: stars),
            ]),
            child: const Text('열기'),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final w = tester.widget<SummonSparks>(find.byType(SummonSparks));
      // 다음 sparksFor()가 새 다이얼로그를 열 수 있게 이번 것을 닫는다 —
      // 안 닫으면 같은 Navigator에 남은 이 연출이 다음 호출의 탭을 먹는다.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      return w.count;
    }

    expect(await sparksFor(5), greaterThan(await sparksFor(1)));
  });
}
