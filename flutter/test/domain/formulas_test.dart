import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/formulas.dart';
import 'package:idle_fantasy/domain/number_format.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

void main() {
  const c = BalanceConfig();

  group('수치 공식 (GAME_DESIGN 4장)', () {
    test('몬스터 HP = 10 × 1.18^stage', () {
      expect(monsterHp(1, c), closeTo(11.8, 1e-9));
      expect(monsterHp(10, c), closeTo(10 * 5.2338, 1e-2));
    });

    test('보스 HP는 일반의 10배', () {
      expect(bossHp(7, c), closeTo(monsterHp(7, c) * 10, 1e-9));
    });

    test('골드 보상 = 5 × 1.15^stage, 성장률이 HP보다 낮다', () {
      expect(goldReward(1, c), closeTo(5.75, 1e-9));
      expect(c.goldGrowth, lessThan(c.monsterHpGrowth));
    });

    test('업그레이드 비용 = base × 1.09^level', () {
      expect(UpgradeType.attack.cost(0, c), 10);
      expect(UpgradeType.attack.cost(1, c), closeTo(10.9, 1e-9));
      expect(UpgradeType.attack.cost(10, c), closeTo(10 * 2.3674, 1e-3));
    });

    test('능력치는 레벨에 선형', () {
      final s0 = Stats.fromLevels(const {}, c);
      final s3 = Stats.fromLevels(const {UpgradeType.attack: 3}, c);
      expect(s3.attack - s0.attack, 15);
    });

    test('치명타 확률은 100%를 넘지 않는다', () {
      final s = Stats.fromLevels(const {UpgradeType.critChance: 500}, c);
      expect(s.critChance, 1.0);
    });
  });

  group('숫자 포맷', () {
    test('1000 미만은 정수', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(999.9), '999');
    });
    test('한글 단위', () {
      expect(formatNumber(1230), '1230', reason: '만 미만은 그대로');
      expect(formatNumber(45600000), '4560만');
      expect(formatNumber(12340000), '1234만');
      expect(formatNumber(100000000), '1억');
      expect(formatNumber(123400000000), '1234억');
      expect(formatNumber(1000000000000), '1조');
      expect(formatNumber(20000), '2만');
    });
  });
}
