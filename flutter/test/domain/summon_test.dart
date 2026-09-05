import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/summon.dart';

void main() {
  const config = BalanceConfig();

  group('용화 단계', () {
    test('네 칸이 비면 0단계', () {
      expect(SummonState.empty.dragonStage, 0);
    });

    test('성급 합을 4로 나눈다 — 내림', () {
      // 합 7 → 1단계. 한 칸에 몰려 있어도 같다.
      const spread = SummonState(relics: {RelicSlot.horn: 2, RelicSlot.tail: 2, RelicSlot.wing: 2, RelicSlot.scale: 1});
      const piled = SummonState(relics: {RelicSlot.horn: 5, RelicSlot.tail: 2});
      expect(spread.totalStars, 7);
      expect(piled.totalStars, 7);
      expect(spread.dragonStage, 1);
      expect(piled.dragonStage, 1, reason: '몰아 키우든 고루 키우든 합이 같으면 같다 (스펙 3.3)');
    });

    test('네 칸이 다 ★5면 5단계', () {
      const full = SummonState(relics: {RelicSlot.horn: 5, RelicSlot.tail: 5, RelicSlot.wing: 5, RelicSlot.scale: 5});
      expect(full.dragonStage, 5);
    });
  });

  group('보정값', () {
    test('성급 0은 보정이 없다', () => expect(relicBonus(0), 0));
    test('성급이 오를수록 커진다', () {
      final values = [for (var s = 0; s <= 5; s++) relicBonus(s)];
      expect(values, [0, 0.04, 0.09, 0.15, 0.22, 0.30]);
    });
    test('용화 배수는 단계마다 곱해진다', () {
      expect(dragonMultiplier(0, config), 1.0);
      expect(dragonMultiplier(2, config), closeTo(1.06 * 1.06, 1e-9));
    });
  });

  group('저장', () {
    test('싣고 내리면 그대로다', () {
      const before = SummonState(stones: 240, relics: {RelicSlot.horn: 3, RelicSlot.scale: 1}, pityCount: 12, regionsRewarded: 2);
      final after = SummonState.fromJson(before.toJson());
      expect(after.stones, 240);
      expect(after.starsOf(RelicSlot.horn), 3);
      expect(after.starsOf(RelicSlot.scale), 1);
      expect(after.starsOf(RelicSlot.tail), 0);
      expect(after.pityCount, 12);
      expect(after.regionsRewarded, 2);
    });

    test('빈 json이면 빈 상태다 — 옛 저장이 열려야 한다', () {
      expect(SummonState.fromJson(const {}).stones, 0);
      expect(SummonState.fromJson(const {}).dragonStage, 0);
    });
  });

  group('굴리기', () {
    test('성급 분포가 표와 맞는다', () {
      // 고정 씨앗으로 1만 번 굴려 표(60/25/10/4/1)에 가까운지 본다.
      final rng = Random(7);
      final counts = <int, int>{};
      for (var i = 0; i < 10000; i++) {
        final r = rollRelic(rng, pityReached: false);
        counts[r.stars] = (counts[r.stars] ?? 0) + 1;
      }
      expect(counts[1]! / 10000, closeTo(0.60, 0.03));
      expect(counts[2]! / 10000, closeTo(0.25, 0.03));
      expect(counts[3]! / 10000, closeTo(0.10, 0.02));
      expect(counts[4]! / 10000, closeTo(0.04, 0.015));
      expect(counts[5]! / 10000, closeTo(0.01, 0.01));
    });

    test('부위는 균등하다', () {
      final rng = Random(11);
      final counts = <RelicSlot, int>{};
      for (var i = 0; i < 8000; i++) {
        final r = rollRelic(rng, pityReached: false);
        counts[r.slot] = (counts[r.slot] ?? 0) + 1;
      }
      for (final slot in RelicSlot.values) {
        expect(counts[slot]! / 8000, closeTo(0.25, 0.03), reason: slot.label);
      }
    });

    test('천장에 닿으면 ★5가 확정으로 나온다', () {
      final rng = Random(3);
      for (var i = 0; i < 50; i++) {
        final r = rollRelic(rng, pityReached: true);
        expect(r.stars, 5);
        expect(r.byPity, isTrue);
      }
    });
  });

  group('승급', () {
    test('빈 칸이면 나온 성급 그대로', () {
      final (after, results) = summonRelics(
        const SummonState(stones: 300), Random(1), config, count: 1);
      final slot = results.single.slot;
      expect(after.starsOf(slot), results.single.stars);
    });

    test('이미 있으면 최소 +1 오른다 — 헛도는 소환이 없다', () {
      // 뿔 ★3을 갖고 뿔 ★1이 나와도 ★4가 된다.
      expect(mergeStars(current: 3, rolled: 1), 4);
      expect(mergeStars(current: 3, rolled: 5), 5);
      expect(mergeStars(current: 0, rolled: 2), 2);
      expect(mergeStars(current: 5, rolled: 1), 5, reason: '상한을 넘지 않는다');
    });
  });

  group('소환 실행', () {
    test('소환석이 모자라면 아무 일도 없다', () {
      const poor = SummonState(stones: 10);
      final (after, results) = summonRelics(poor, Random(1), config, count: 1);
      expect(results, isEmpty);
      expect(after.stones, 10, reason: '값을 안 깎는다');
    });

    test('1회는 summonCost를, 10회는 summonTenCost를 깎는다', () {
      final (one, _) = summonRelics(const SummonState(stones: 1000), Random(1), config, count: 1);
      expect(one.stones, 1000 - config.summonCost);
      final (ten, tenResults) = summonRelics(const SummonState(stones: 1000), Random(1), config, count: 10);
      expect(ten.stones, 1000 - config.summonTenCost);
      expect(tenResults, hasLength(10));
    });

    test('천장 카운터가 오르고 ★5에서 0으로 돌아간다', () {
      // 천장 직전까지 채운 상태에서 한 번 뽑으면 ★5가 나오고 카운터가 0이 된다.
      final start = SummonState(stones: 1000, pityCount: config.summonPity - 1);
      final (after, results) = summonRelics(start, Random(5), config, count: 1);
      expect(results.single.stars, 5);
      expect(after.pityCount, 0);
    });
  });
}
