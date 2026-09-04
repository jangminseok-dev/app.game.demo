import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/equipment.dart';

void main() {
  const common = Equipment(slot: EquipSlot.weapon, grade: EquipGrade.common, tier: 0);
  const legendary = Equipment(slot: EquipSlot.weapon, grade: EquipGrade.legendary, tier: 0);

  group('장비 획득', () {
    test('빈 부위면 바로 착용한다', () {
      final s = EquipmentState.empty.pickUp(common);
      expect(s.equipped[EquipSlot.weapon], common);
      expect(s.inventory, isEmpty);
    });

    test('더 센 것을 얻으면 교체하고 쓰던 것은 인벤토리로 간다', () {
      final s = EquipmentState.empty.pickUp(common).pickUp(legendary);
      expect(s.equipped[EquipSlot.weapon], legendary);
      expect(s.inventory, [common]);
    });

    test('약한 것을 얻으면 착용은 그대로, 새 것이 인벤토리로 간다', () {
      final s = EquipmentState.empty.pickUp(legendary).pickUp(common);
      expect(s.equipped[EquipSlot.weapon], legendary);
      expect(s.inventory, [common]);
    });
  });

  group('분해와 강화', () {
    test('일괄 분해는 인벤토리만 비우고 착용분은 남긴다', () {
      final s = EquipmentState.empty.pickUp(legendary).pickUp(common).pickUp(common).scrapAll();
      expect(s.inventory, isEmpty);
      expect(s.equipped[EquipSlot.weapon], legendary);
      expect(s.stones, common.scrapValue * 2);
    });

    test('강화석이 모자라면 아무것도 바뀌지 않는다', () {
      const s = EquipmentState(stones: 0);
      expect(s.canEnhance, isFalse);
      expect(s.enhance().enhanceLevel, 0);
    });

    test('강화는 파괴도 하락도 없이 한 단계씩 오른다', () {
      var s = const EquipmentState(stones: 1000);
      for (var i = 0; i < 10; i++) {
        s = s.enhance();
      }
      expect(s.enhanceLevel, 10, reason: '실패가 없다');
      expect(s.stones, lessThan(1000));
    });

    test('강화 비용은 레벨이 오를수록 비싸진다', () {
      const a = EquipmentState(enhanceLevel: 0);
      const b = EquipmentState(enhanceLevel: 20);
      expect(b.enhanceCost, greaterThan(a.enhanceCost));
    });

    test('강화 레벨은 장비를 바꿔도 유지된다 — 캐릭터 귀속', () {
      final s = const EquipmentState(stones: 100).enhance().pickUp(legendary);
      expect(s.enhanceLevel, 1);
    });
  });

  group('전투력 기여', () {
    test('아무것도 없으면 배수 1', () {
      expect(EquipmentState.empty.power, 1.0);
    });

    test('장비와 강화가 배수를 올린다', () {
      final geared = EquipmentState.empty.pickUp(legendary);
      expect(geared.power, greaterThan(1.0));
      final enhanced = const EquipmentState(stones: 100).enhance();
      expect(enhanced.power, closeTo(1 + EquipmentState.enhancePerLevel, 1e-9));
    });
  });

  group('드롭 테이블', () {
    test('티어는 50층마다 한 단계', () {
      expect(DropTable.tierOf(1), 0);
      expect(DropTable.tierOf(50), 0);
      expect(DropTable.tierOf(51), 1);
      expect(DropTable.tierOf(120), 2);
    });

    test('보스는 층 구간마다 담당 부위가 고정이다', () {
      expect(DropTable.bossSlotFor(10), DropTable.bossSlotFor(40), reason: '같은 티어면 같은 부위');
      expect(DropTable.bossSlotFor(10), isNot(DropTable.bossSlotFor(60)), reason: '다음 티어는 다른 부위');
    });

    test('보스는 반드시 떨어뜨리고 부위가 고정이다', () {
      const table = DropTable();
      final rng = Random(1);
      for (var i = 0; i < 30; i++) {
        final item = table.roll(70, isBoss: true, rng: rng);
        expect(item, isNotNull);
        expect(item!.slot, DropTable.bossSlotFor(70));
        expect(item.tier, 1);
      }
    });

    test('필드 드롭은 가끔만 나온다', () {
      const table = DropTable(fieldChance: 0.1);
      final rng = Random(7);
      final drops = [for (var i = 0; i < 1000; i++) table.roll(1, isBoss: false, rng: rng)].whereType<Equipment>();
      expect(drops.length, inInclusiveRange(60, 140), reason: '기대값 100 근처');
    });

    test('전설이 일반보다 드물다', () {
      const table = DropTable(fieldChance: 1);
      final rng = Random(3);
      final drops = [for (var i = 0; i < 2000; i++) table.roll(1, isBoss: false, rng: rng)!];
      final common = drops.where((e) => e.grade == EquipGrade.common).length;
      final legendary = drops.where((e) => e.grade == EquipGrade.legendary).length;
      expect(legendary, lessThan(common));
      expect(legendary, greaterThan(0), reason: '아예 안 나오지는 않는다');
    });
  });

  group('저장', () {
    test('JSON 왕복 후 같다', () {
      final s = const EquipmentState(stones: 42)
          .pickUp(legendary)
          .pickUp(const Equipment(slot: EquipSlot.ring, grade: EquipGrade.rare, tier: 2))
          .pickUp(common)
          .enhance();
      final back = EquipmentState.fromJson(s.toJson());
      expect(back.equipped, s.equipped);
      expect(back.inventory, s.inventory);
      expect(back.stones, s.stones);
      expect(back.enhanceLevel, s.enhanceLevel);
    });

    test('빈 JSON도 읽힌다 — 장비 이전 저장', () {
      final back = EquipmentState.fromJson(const {});
      expect(back.equipped, isEmpty);
      expect(back.enhanceLevel, 0);
    });
  });
}
