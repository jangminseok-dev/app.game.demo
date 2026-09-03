import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/monster.dart';

import '../support/catalog.dart';

void main() {
  test('번들 에셋은 서버 마스터 데이터와 같은 파일이다', () {
    final bundled = jsonDecode(File('assets/monsters.json').readAsStringSync());
    final server = jsonDecode(
      File('../backend/apps/masterdata/resources/monsters.json').readAsStringSync(),
    );
    expect(bundled, server, reason: 'backend/apps/masterdata/resources/monsters.json을 assets/로 복사할 것');
  });

  test('100종 · 10지역 · 지역당 10종', () {
    final c = loadBundledCatalog();
    expect(c.monsters.length, 100);
    expect(c.regions.length, 10);
    for (final r in c.regions) {
      expect(c.monstersIn(r.id).length, 10, reason: r.id);
    }
    expect(c.monsters.map((m) => m.id).toSet().length, 100);
  });

  test('스테이지 → 몬스터 매핑은 서버와 같은 규칙 (지역 안 순환)', () {
    final c = loadBundledCatalog();
    expect(c.forStage(1)!.id, 1);
    expect(c.forStage(10)!.id, 10);
    expect(c.forStage(11)!.id, 1);
    expect(c.forStage(50)!.id, 10);
    expect(c.forStage(51)!.id, 11);
    expect(c.forStage(121)!.id, 21);
    expect(c.forStage(1101)!.id, 91);
    expect(c.forStage(9999)!.region, 'demon');
  });

  test('빈 카탈로그는 null을 돌려준다', () {
    expect(MonsterCatalog.empty.forStage(1), isNull);
    expect(MonsterCatalog.empty.byId(1), isNull);
  });
}
