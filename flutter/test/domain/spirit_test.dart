import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/spirit.dart';
import 'package:idle_fantasy/domain/summon.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

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
        pityCount: 12,
      );
      final after = SpiritState.fromJson(before.toJson());
      expect(after.starsOf(SpiritId.moss), 3);
      expect(after.starsOf(SpiritId.ember), 1);
      expect(after.active, SpiritId.moss);
      expect(after.gauge, closeTo(0.4, 1e-9));
      expect(after.firedCount, 7);
      expect(after.pityCount, 12);
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

  group('전투 루프', () {
    BattleEngine engine() => const BattleEngine(BalanceConfig());

    // 이름을 `withSpirit` 으로 두지 마라 — 같은 파일에서 `stats.withSpirit(...)` 을 부른다.
    GameState stateWith(SpiritId id, int stars) => GameState.initial(config).copyWith(
          spirits: SpiritState(owned: {id: stars}, active: id),
        );

    test('게이지는 시간으로 찬다', () {
      var s = stateWith(SpiritId.crystal, 1);
      s = engine().tick(s, 9, Random(1));
      expect(s.spirits.gauge, closeTo(9 / config.spiritGaugeSeconds, 0.02),
          reason: '90초에 1이 되는 속도다');
    });

    test('데리고 다니는 정령이 없으면 안 찬다', () {
      var s = GameState.initial(config);
      s = engine().tick(s, 30, Random(1));
      expect(s.spirits.gauge, 0);
    });

    test('가득 차면 나오고 게이지가 0으로 돌아간다', () {
      var s = stateWith(SpiritId.crystal, 3).copyWith(
        spirits: SpiritState(owned: const {SpiritId.crystal: 3}, active: SpiritId.crystal, gauge: 0.99),
      );
      final before = s.spirits.firedCount;
      s = engine().tick(s, 2, Random(1));
      expect(s.spirits.firedCount, before + 1, reason: '화면이 이 값으로 컷신을 띄운다');
      expect(s.spirits.gauge, lessThan(0.2), reason: '나오면 0으로 돌아간다');
    });

    test('이끼는 주인공을 회복시킨다', () {
      var s = stateWith(SpiritId.moss, 3);
      final maxHp = s.maxHeroHp(config);
      s = s.copyWith(
        heroHp: maxHp * 0.3,
        spirits: SpiritState(owned: const {SpiritId.moss: 3}, active: SpiritId.moss, gauge: 1),
      );
      s = engine().tick(s, 0.1, Random(1));
      // 0.3만 넘으면 자연 회복만으로도 통과한다 — 0.42(0.3 + spiritHealRatio 0.12)에 못 미치는
      // 0.4로 문턱을 올려서 회복이 실제로 걸렸는지를 본다.
      expect(s.heroHpOr(config), greaterThan(maxHp * 0.4));
    });

    test('잿불은 화상을, 서리는 둔화를 남긴다', () {
      var burn = stateWith(SpiritId.ember, 2).copyWith(
        spirits: SpiritState(owned: const {SpiritId.ember: 2}, active: SpiritId.ember, gauge: 1),
      );
      burn = engine().tick(burn, 0.1, Random(1));
      expect(burn.spirits.burnLeft, greaterThan(0));
      expect(burn.spirits.slowLeft, 0);

      var slow = stateWith(SpiritId.frost, 2).copyWith(
        spirits: SpiritState(owned: const {SpiritId.frost: 2}, active: SpiritId.frost, gauge: 1),
      );
      slow = engine().tick(slow, 0.1, Random(1));
      expect(slow.spirits.slowLeft, greaterThan(0));
      expect(slow.spirits.burnLeft, 0);
    });

    test('화상과 둔화는 시간이 지나면 사라진다', () {
      var s = stateWith(SpiritId.ember, 1).copyWith(
        spirits: const SpiritState(
            owned: {SpiritId.ember: 1}, active: SpiritId.ember, burnLeft: 1, slowLeft: 1),
      );
      s = engine().tick(s, 2, Random(1));
      expect(s.spirits.burnLeft, 0);
      expect(s.spirits.slowLeft, 0);
    });

    test('평소 보정이 공격력에 걸린다', () {
      const stats = Stats(attack: 100, attacksPerSecond: 2, critChance: 0.1, goldMultiplier: 1);
      const none = SpiritState();
      expect(stats.withSpirit(none, config).attack, 100);

      const five = SpiritState(owned: {SpiritId.moss: 5}, active: SpiritId.moss);
      expect(stats.withSpirit(five, config).attack, closeTo(100 * 1.10, 1e-6));
    });

    test('statsWith가 정령을 거친다 — 사슬에 붙어 있어야 한다', () {
      final bare = GameState.initial(config);
      final withIt = bare.copyWith(
        spirits: const SpiritState(owned: {SpiritId.moss: 5}, active: SpiritId.moss),
      );
      expect(withIt.statsWith(config).attack, greaterThan(bare.statsWith(config).attack));
    });

    test('수정은 하나만 때리는 대신 세게 때린다', () {
      // GameState.initial은 무리가 3~5마리라 무리 크기에 기대면 결과가 뒤집힌다.
      // 한 마리로 줄여 targets가 둘 다 1이 되게 만들고 배수 차이만 남긴다.
      GameState oneMonster(SpiritId id) {
        final s = stateWith(id, 3).copyWith(
          spirits: SpiritState(owned: {id: 3}, active: id, gauge: 1),
        );
        return s.copyWith(wave: [s.wave.first.copyWith(hp: 1e9)]);
      }

      final crystal = engine().tick(oneMonster(SpiritId.crystal), 0.1, Random(1));
      final frost = engine().tick(oneMonster(SpiritId.frost), 0.1, Random(1));
      final crystalHp = crystal.wave.fold<double>(0, (a, m) => a + m.hp);
      final frostHp = frost.wave.fold<double>(0, (a, m) => a + m.hp);
      expect(crystalHp, lessThan(frostHp), reason: '한 마리뿐일 때는 수정이 더 아프다');
    });

    test('전역 제약 두 값이 코드에 잠겨 있다', () {
      expect(config.spiritGaugeSeconds, 90, reason: '60 아래로 내리면 스펙 4.3의 근거가 무너진다');
      expect(config.spiritBossGaugeRate, 1.5);
    });

    test('보스전에서는 1.5배 빨리 찬다', () {
      final normal = engine().tick(stateWith(SpiritId.crystal, 1), 9, Random(1));
      final boss = engine().tick(
          stateWith(SpiritId.crystal, 1).copyWith(isBoss: true, bossTimeLeft: config.bossTimeLimit),
          9,
          Random(1));
      expect(boss.spirits.gauge, closeTo(normal.spirits.gauge * 1.5, 0.01));
    });
  });

  group('정령 소환', () {
    test('종류는 균등하다', () {
      final rng = Random(11);
      final counts = <SpiritId, int>{};
      var stones = const SummonState(stones: 1000000);
      var spirits = SpiritState.empty;
      for (var i = 0; i < 8000; i++) {
        final (s2, sp2, r) = summonSpirits(stones, spirits, rng, config, count: 1);
        stones = s2;
        spirits = sp2;
        counts[r.single.id] = (counts[r.single.id] ?? 0) + 1;
      }
      for (final id in SpiritId.values) {
        expect(counts[id]! / 8000, closeTo(0.25, 0.03), reason: id.label);
      }
    });

    test('성급 상한이 ★5다 — 유물의 ★10이 아니다', () {
      final rng = Random(3);
      var stones = const SummonState(stones: 1000000);
      var spirits = SpiritState.empty;
      for (var i = 0; i < 500; i++) {
        final (s2, sp2, _) = summonSpirits(stones, spirits, rng, config, count: 1);
        stones = s2;
        spirits = sp2;
      }
      for (final id in SpiritId.values) {
        expect(spirits.starsOf(id), lessThanOrEqualTo(SpiritState.maxStars), reason: id.label);
      }
      expect(spirits.owned.values.any((v) => v == SpiritState.maxStars), isTrue,
          reason: '500번이면 하나는 만렙이다');
    });

    test('소환석이 모자라면 아무 일도 없다', () {
      const poor = SummonState(stones: 10);
      final (after, spirits, results) =
          summonSpirits(poor, SpiritState.empty, Random(1), config, count: 1);
      expect(results, isEmpty);
      expect(after.stones, 10);
      expect(spirits.owned, isEmpty);
    });

    test('결과 한 줄이 승급을 보여 준다', () {
      const fresh = SpiritSummonResult(id: SpiritId.moss, stars: 2, byPity: false, before: 0, after: 2);
      const up = SpiritSummonResult(id: SpiritId.frost, stars: 1, byPity: false, before: 3, after: 4);
      expect(fresh.line.text, '이끼의 꿈 ★2');
      expect(up.line.text, '서리의 꿈 ★3 → ★4');
    });

    test('상한에 닿은 정령은 승급 화살표를 안 그린다', () {
      const capped = SpiritSummonResult(
          id: SpiritId.ember, stars: 1, byPity: false,
          before: SpiritState.maxStars, after: SpiritState.maxStars);
      expect(capped.line.text, '잿불의 꿈 ★5');
    });

    test('천장은 유물과 따로 센다 — 한쪽만 뽑는 사람이 손해 보지 않는다', () {
      // 유물 천장을 거의 채운 상태에서 정령을 뽑아도 유물 카운터는 안 줄어든다.
      final stones = SummonState(stones: 100000, pityCount: config.summonPity - 1);
      final (after, spirits, _) =
          summonSpirits(stones, SpiritState.empty, Random(1), config, count: 1);
      expect(after.pityCount, config.summonPity - 1, reason: '유물 카운터는 그대로다');
      expect(spirits.pityCount, 1, reason: '정령은 자기 카운터를 센다');
    });

    test('정령 천장도 ★5를 확정으로 준다', () {
      final spirits = SpiritState(pityCount: config.summonPity - 1);
      final (_, after, results) = summonSpirits(
          const SummonState(stones: 100000), spirits, Random(5), config, count: 1);
      expect(results.single.stars, SpiritState.maxStars);
      expect(after.pityCount, 0, reason: '★5가 나오면 0으로 돌아간다');
    });
  });
}
