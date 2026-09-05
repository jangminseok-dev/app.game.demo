import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/spirit.dart';

void main() {
  const config = BalanceConfig();

  group('정령 4종', () {
    test('넷이고 이름과 효과가 다 다르다', () {
      expect(SpiritId.values, hasLength(4));
      expect(SpiritId.values.map((s) => s.label).toSet(), hasLength(4));
      expect(SpiritId.values.map((s) => s.effect).toSet(), hasLength(4),
          reason: '넷이 같은 일을 하면 고를 이유가 없다');
    });

    test('이름은 스펙 4.4 그대로다', () {
      expect(SpiritId.moss.label, '이끼의 꿈');
      expect(SpiritId.crystal.label, '수정의 꿈');
      expect(SpiritId.ember.label, '잿불의 꿈');
      expect(SpiritId.frost.label, '서리의 꿈');
    });
  });

  group('상태', () {
    test('빈 상태는 편성도 게이지도 없다', () {
      expect(SpiritState.empty.active, isNull);
      expect(SpiritState.empty.gauge, 0);
      expect(SpiritState.empty.activeStars, 0);
      expect(SpiritState.empty.isReady, isFalse);
    });

    test('게이지가 1이면 준비된 것이다 — 편성이 있어야 한다', () {
      const noSpirit = SpiritState(gauge: 1);
      expect(noSpirit.isReady, isFalse, reason: '데리고 다니는 정령이 없으면 나올 것이 없다');

      const ready = SpiritState(owned: {SpiritId.moss: 2}, active: SpiritId.moss, gauge: 1);
      expect(ready.isReady, isTrue);
      expect(ready.activeStars, 2);
    });

    test('편성한 정령의 성급을 읽는다', () {
      const s = SpiritState(owned: {SpiritId.moss: 3, SpiritId.frost: 1}, active: SpiritId.frost);
      expect(s.starsOf(SpiritId.moss), 3);
      expect(s.activeStars, 1);
      expect(s.starsOf(SpiritId.ember), 0);
    });
  });

  group('세기', () {
    test('성급이 오를수록 피해가 는다', () {
      expect(spiritDamageMultiplier(1, config), config.spiritDamageBase);
      expect(spiritDamageMultiplier(5, config),
          config.spiritDamageBase + config.spiritDamagePerStar * 4);
      expect(spiritDamageMultiplier(0, config), 0, reason: '없는 정령은 피해가 없다');
    });

    test('평소 보정도 성급을 따른다', () {
      expect(spiritPassive(0, config), 0);
      expect(spiritPassive(5, config), closeTo(config.spiritPassivePerStar * 5, 1e-9));
    });
  });

  group('저장', () {
    test('싣고 내리면 그대로다', () {
      const before = SpiritState(
        owned: {SpiritId.moss: 3, SpiritId.ember: 1},
        active: SpiritId.moss,
        gauge: 0.4,
        firedCount: 7,
      );
      final after = SpiritState.fromJson(before.toJson());
      expect(after.starsOf(SpiritId.moss), 3);
      expect(after.starsOf(SpiritId.ember), 1);
      expect(after.active, SpiritId.moss);
      expect(after.gauge, closeTo(0.4, 1e-9));
      expect(after.firedCount, 7);
    });

    test('빈 json이면 빈 상태다 — 옛 저장이 열려야 한다', () {
      expect(SpiritState.fromJson(const {}).active, isNull);
      expect(SpiritState.fromJson(const {}).gauge, 0);
    });

    test('지속 효과는 저장하지 않는다 — 전투가 끝나면 사라지는 것이다', () {
      const burning = SpiritState(burnLeft: 3, slowLeft: 2);
      final after = SpiritState.fromJson(burning.toJson());
      expect(after.burnLeft, 0);
      expect(after.slowLeft, 0);
    });
  });
}
