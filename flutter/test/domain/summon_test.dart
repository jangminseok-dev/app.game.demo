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
}
