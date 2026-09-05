import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/quest.dart';
import 'package:idle_fantasy/domain/daily.dart';
import 'package:idle_fantasy/domain/attendance.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/monster.dart';
import 'package:idle_fantasy/domain/summon.dart';
import 'package:idle_fantasy/domain/upgrade.dart';

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
      expect(mergeStars(current: 5, rolled: 1), 6, reason: '★5는 더 이상 끝이 아니다 — 상한은 ★10이다');
      expect(mergeStars(current: SummonState.maxStars, rolled: 1), SummonState.maxStars,
          reason: '상한을 넘지 않는다');
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

  group('스탯 반영', () {
    test('유물이 없으면 스탯이 그대로다', () {
      const stats = Stats(attack: 100, attacksPerSecond: 2, critChance: 0.1, goldMultiplier: 1);
      final after = stats.withRelics(SummonState.empty, config);
      expect(after.attack, 100);
      expect(after.attacksPerSecond, 2);
      expect(after.critChance, 0.1);
      expect(after.goldMultiplier, 1);
    });

    test('뿔은 공격력, 꼬리는 공속, 날개는 치명타에 걸린다', () {
      const stats = Stats(attack: 100, attacksPerSecond: 2, critChance: 0.1, goldMultiplier: 1);
      // 뿔 ★5(+30%) 하나뿐이면 성급 합 5 → 용화 1단계(×1.06).
      const one = SummonState(relics: {RelicSlot.horn: 5});
      final a = stats.withRelics(one, config);
      expect(a.attack, closeTo(100 * 1.30 * 1.06, 1e-6));
      expect(a.attacksPerSecond, 2, reason: '꼬리가 없으므로 그대로다 — 용화 배수는 공격력에만 걸린다');

      const wing = SummonState(relics: {RelicSlot.wing: 3});
      expect(stats.withRelics(wing, config).critChance, closeTo(0.1 + 0.15, 1e-6),
          reason: '치명타는 더하기다 — 곱하면 1.0을 넘긴다');
    });

    test('용화 배수는 공격력에만 걸린다 — DPS가 제곱이 되면 장비를 이긴다', () {
      const stats = Stats(attack: 100, attacksPerSecond: 2, critChance: 0.1, goldMultiplier: 1);
      // 꼬리★5만: 합 5 → 용화 1단계. 공속은 유물 보정 1.30만 받고 용화 배수는 안 받는다.
      const tail = SummonState(relics: {RelicSlot.tail: 5});
      final a = stats.withRelics(tail, config);
      expect(a.attacksPerSecond, closeTo(2 * 1.30, 1e-6));
      expect(a.attack, closeTo(100 * 1.06, 1e-6), reason: '뿔이 없어도 공격력에는 용화 배수가 걸린다');
      expect(a.goldMultiplier, 1, reason: '골드에는 전용 유물도 용화 배수도 없다');
    });

    test('치명타는 1.0을 넘지 않는다', () {
      const stats = Stats(attack: 1, attacksPerSecond: 1, critChance: 0.95, goldMultiplier: 1);
      const wing = SummonState(relics: {RelicSlot.wing: 5});
      expect(stats.withRelics(wing, config).critChance, 1.0);
    });

    test('비늘은 최대 체력에 걸리고 용화 배수도 곱해진다', () {
      final bare = GameState.initial(config);
      final scaled = bare.copyWith(summon: const SummonState(relics: {RelicSlot.scale: 4}));
      // 비늘★4 = 합 4 → 용화 1단계. 유물 보정 1.22에 용화 1.06이 곱해진다.
      expect(scaled.maxHeroHp(config), closeTo(bare.maxHeroHp(config) * 1.22 * 1.06, 1e-6));

      // 용화 배수가 빠지면 이 단언이 깨진다 — 비늘★1은 합 1이라 0단계다.
      final noStage = bare.copyWith(summon: const SummonState(relics: {RelicSlot.scale: 1}));
      expect(noStage.maxHeroHp(config), closeTo(bare.maxHeroHp(config) * 1.04, 1e-6));
    });

    test('statsWith가 유물을 거친다 — 사슬에 붙어 있어야 한다', () {
      final bare = GameState.initial(config);
      final horned = bare.copyWith(summon: const SummonState(relics: {RelicSlot.horn: 5}));
      expect(horned.statsWith(config).attack, greaterThan(bare.statsWith(config).attack));
    });
  });

  group('깊어진 유물 축', () {
    test('성급 상한은 ★10이다', () {
      expect(SummonState.maxStars, 10);
    });

    test('용화 단계는 5에서 멈춘다 — 아트 표가 5단계뿐이다', () {
      // 네 칸 다 ★10이면 합 40, 4로 나누면 10이지만 단계는 5가 끝이다.
      const full = SummonState(relics: {
        RelicSlot.horn: 10, RelicSlot.tail: 10, RelicSlot.wing: 10, RelicSlot.scale: 10,
      });
      expect(full.totalStars, 40);
      expect(full.dragonStage, 5);
      expect(SummonState.maxDragonStage, 5);
    });

    test('★5 뒤 보정은 완만해진다', () {
      final values = [for (var s = 0; s <= 10; s++) relicBonus(s)];
      expect(values, [0, 0.04, 0.09, 0.15, 0.22, 0.30, 0.33, 0.36, 0.38, 0.39, 0.40]);
      // 증가폭이 줄어든다 — 깊은 성급은 길이를 벌지 힘을 벌지 않는다.
      final steps = [for (var s = 1; s <= 10; s++) values[s] - values[s - 1]];
      for (var i = 5; i < steps.length; i++) {
        expect(steps[i], lessThanOrEqualTo(steps[i - 1] + 1e-9), reason: '★${i + 1} 증가폭');
      }
    });

    test('상한이 올라도 굴려 나오는 최고 성급은 ★5다', () {
      expect(maxRolledStars, 5);
      final rng = Random(3);
      for (var i = 0; i < 200; i++) {
        expect(rollRelic(rng, pityReached: false).stars, lessThanOrEqualTo(5));
      }
    });

    test('천장은 상한이 아니라 확률표 꼭대기(★5)를 준다', () {
      final r = rollRelic(Random(1), pityReached: true);
      expect(r.stars, 5, reason: '★10을 주면 천장 하나로 한 칸이 끝난다');
      expect(r.byPity, isTrue);
    });

    test('천장 카운터는 굴린 ★5에서 초기화된다 — 상한 기준이면 영영 안 걸린다', () {
      final start = SummonState(stones: 10000, pityCount: config.summonPity - 1);
      final (after, results) = summonRelics(start, Random(5), config, count: 1);
      expect(results.single.stars, 5);
      expect(after.pityCount, 0);
    });

    test('만렙은 네 칸이 다 ★10일 때다', () {
      const nine = SummonState(relics: {
        RelicSlot.horn: 10, RelicSlot.tail: 10, RelicSlot.wing: 10, RelicSlot.scale: 9,
      });
      expect(nine.isMaxed, isFalse);
      expect(nine.copyWith(relics: {
        RelicSlot.horn: 10, RelicSlot.tail: 10, RelicSlot.wing: 10, RelicSlot.scale: 10,
      }).isMaxed, isTrue);
    });
  });

  group('접속 보상이 계수와 같다', () {
    test('오늘 과제 처치 보상 = summonStonePerDaily', () {
      expect(DailyGoal.kills.reward, RewardKind.summonStone);
      expect(DailyGoal.kills.rewardAmount, config.summonStonePerDaily);
    });

    test('출석부에 소환석 칸이 있고 그 양이 summonStonePerAttendance다', () {
      final stoneSlots = attendanceTable.where((e) => e.$1 == RewardKind.summonStone).toList();
      expect(stoneSlots, hasLength(1), reason: '주당 한 칸');
      expect(stoneSlots.single.$2, config.summonStonePerAttendance);
    });
  });

  group('지역 첫 진입', () {
    BattleEngine engineWith(MonsterCatalog catalog) => BattleEngine(config, catalog: catalog);

    test('지역을 처음 밟을 때마다 소환석을 준다', () {
      final after = engineWith(_twoRegionCatalog()).grantRegionStones(GameState.initial(config));
      expect(after.summon.stones, config.summonStonePerRegion, reason: '첫 지역 하나');
      expect(after.summon.regionsRewarded, 1);
    });

    test('같은 지역에서 또 부르면 안 준다 — 여러 번 불려도 안전해야 한다', () {
      final engine = engineWith(_twoRegionCatalog());
      final once = engine.grantRegionStones(GameState.initial(config));
      final twice = engine.grantRegionStones(once);
      expect(twice.summon.stones, once.summon.stones);
    });

    test('여러 지역을 건너뛰어도 밀린 만큼 다 준다', () {
      final after = engineWith(_twoRegionCatalog())
          .grantRegionStones(GameState.initial(config).copyWith(highestStage: 500));
      expect(after.summon.stones, config.summonStonePerRegion * 2);
      expect(after.summon.regionsRewarded, 2);
    });

    test('카탈로그가 비면 아무 일도 없다', () {
      final after = engineWith(MonsterCatalog.empty)
          .grantRegionStones(GameState.initial(config).copyWith(highestStage: 500));
      expect(after.summon.stones, 0);
    });
  });
}

/// 지역 둘 — 1~99, 100~(끝). 지역 첫 진입 지급 테스트에만 쓴다.
MonsterCatalog _twoRegionCatalog() => const MonsterCatalog(
      version: 1,
      regions: [
        Region(
          id: 'r1',
          name: '첫 지역',
          stageFrom: 1,
          stageTo: 99,
          completionKind: PassiveKind.attack,
          completionValue: 1,
        ),
        Region(
          id: 'r2',
          name: '둘째 지역',
          stageFrom: 100,
          stageTo: null,
          completionKind: PassiveKind.attack,
          completionValue: 1,
        ),
      ],
      monsters: [],
    );
