import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/sprites/monster_sprite.dart';

import '../support/catalog.dart';

void main() {
  testWidgets('100종 전부 일반·보스·실루엣으로 그려진다 (페인터 예외 없음)', (tester) async {
    final catalog = loadBundledCatalog();
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: Wrap(
            children: [
              for (final m in catalog.monsters) ...[
                MonsterSprite(monster: m, size: 24),
                MonsterSprite(monster: m, size: 24, isBoss: true),
                MonsterSprite(monster: m, size: 24, silhouette: true),
              ],
              const MonsterSprite(monster: null, size: 24),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(MonsterSprite), findsNWidgets(301));
    expect(tester.takeException(), isNull);
  });

  test('팔레트 스왑: 같은 지역 몬스터끼리 형태는 같고 색만 다르다 — 페인터 repaint 조건', () {
    final catalog = loadBundledCatalog();
    final a = MonsterPainter(monster: catalog.byId(1), isBoss: false, silhouette: false);
    final b = MonsterPainter(monster: catalog.byId(2), isBoss: false, silhouette: false);
    final a2 = MonsterPainter(monster: catalog.byId(1), isBoss: false, silhouette: false);
    expect(a.shouldRepaint(b), true);
    expect(a.shouldRepaint(a2), false);
  });

  test('지역 배경은 10지역 전부 정의돼 있다', () {
    final catalog = loadBundledCatalog();
    final fallback = regionColors('unknown');
    for (final r in catalog.regions) {
      expect(regionColors(r.id), isNot(equals(fallback)), reason: r.id);
    }
  });
}
