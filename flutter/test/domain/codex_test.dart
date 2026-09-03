import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/codex.dart';
import 'package:idle_fantasy/domain/monster.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

import '../support/catalog.dart';

void main() {
  group('패시브 합산 (서버 codex/domain/passives.py와 같은 규칙)', () {
    test('성급마다 perStar를 더한다 — 합연산', () {
      final p = computePassives({1: 3, 3: 2}, smallCatalog);
      expect(p.gold, closeTo(1.5, 1e-9));
      expect(p.crit, closeTo(0.4, 1e-9));
      expect(p.attack, 0);
    });

    test('지역을 전부 등록하면 완성 보너스', () {
      expect(computePassives({1: 1, 2: 1}, smallCatalog).attack, 20);
      expect(computePassives({1: 5}, smallCatalog).attack, 0);
    });

    test('빈 도감·빈 카탈로그는 0', () {
      expect(computePassives({}, smallCatalog).isEmpty, true);
      expect(computePassives({1: 5}, MonsterCatalog.empty).isEmpty, true);
    });

    test('지역 완성률', () {
      expect(regionCompletion({1: 2, 3: 1}, smallCatalog), {'forest': (1, 2), 'cave': (1, 2)});
    });
  });

  group('능력치에 반영', () {
    test('공격·골드·공속·포획은 배율, 치명은 %p', () {
      const p = Passives(attack: 50, gold: 20, attackSpeed: 10, crit: 5, capture: 100);
      final s = Stats.fromLevels(const {}, p);
      expect(s.attack, 15);
      expect(s.goldMultiplier, closeTo(1.2, 1e-9));
      expect(s.attacksPerSecond, closeTo(1.1, 1e-9));
      expect(s.critChance, closeTo(0.10, 1e-9));
      expect(s.captureRate, closeTo(0.01, 1e-9));
    });
  });
}
