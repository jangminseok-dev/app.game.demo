import 'dart:math';

import 'balance_config.dart';

/// 유물 네 칸. GAME_DESIGN 18.2의 용 형태 곡선을 주인공에게 건다 —
/// 뿔이 나고, 꼬리가 붙고, 날개막이 생기고, 마지막에 등줄기 비늘이 돋는다.
enum RelicSlot {
  horn('뿔'),
  tail('꼬리'),
  wing('날개'),
  scale('비늘');

  const RelicSlot(this.label);

  final String label;
}

/// 소환석과 유물 네 칸.
///
/// 유물은 부위마다 성급 하나만 갖는다. 중복은 즉시 승급에 쓰이므로
/// 같은 부위를 여러 개 들고 있을 일이 없다(스펙 10절).
class SummonState {
  const SummonState({
    this.stones = 0,
    this.relics = const {},
    this.pityCount = 0,
    this.regionsRewarded = 0,
  });

  static const empty = SummonState();

  /// 유물 성급 상한.
  static const maxStars = 5;

  final int stones;

  /// 부위 → 성급(1~5). 없는 부위는 키가 없다.
  final Map<RelicSlot, int> relics;

  /// ★5 없이 뽑은 횟수. 천장에 닿으면 다음 한 번이 확정이다.
  final int pityCount;

  /// 소환석을 이미 준 지역 수. 지역을 처음 밟을 때만 주려고 센다.
  final int regionsRewarded;

  int starsOf(RelicSlot slot) => relics[slot] ?? 0;

  int get totalStars => RelicSlot.values.fold(0, (a, s) => a + starsOf(s));

  /// 용화 단계 0~5. 네 칸 성급의 합을 4로 나눈다(내림).
  ///
  /// 최솟값으로 재면 한 칸이 안 나올 때 나머지 셋이 통째로 죽는다.
  /// 무료 소환이라 뽑는 횟수가 적어 그 벽이 몇 주가 된다(스펙 3.3).
  int get dragonStage => (totalStars ~/ RelicSlot.values.length).clamp(0, maxStars);

  bool canSummon(BalanceConfig c) => stones >= c.summonCost;
  bool canSummonTen(BalanceConfig c) => stones >= c.summonTenCost;

  SummonState copyWith({
    int? stones,
    Map<RelicSlot, int>? relics,
    int? pityCount,
    int? regionsRewarded,
  }) =>
      SummonState(
        stones: stones ?? this.stones,
        relics: relics ?? this.relics,
        pityCount: pityCount ?? this.pityCount,
        regionsRewarded: regionsRewarded ?? this.regionsRewarded,
      );

  Map<String, dynamic> toJson() => {
        'stones': stones,
        'relics': {for (final e in relics.entries) e.key.name: e.value},
        'pityCount': pityCount,
        'regionsRewarded': regionsRewarded,
      };

  factory SummonState.fromJson(Map<String, dynamic> j) {
    final raw = j['relics'] as Map<String, dynamic>? ?? const {};
    return SummonState(
      stones: (j['stones'] as num? ?? 0).toInt(),
      relics: {
        for (final slot in RelicSlot.values)
          if (raw[slot.name] != null) slot: (raw[slot.name] as num).toInt(),
      },
      pityCount: (j['pityCount'] as num? ?? 0).toInt(),
      regionsRewarded: (j['regionsRewarded'] as num? ?? 0).toInt(),
    );
  }
}

/// 유물 하나가 주는 보정(0~0.30).
const _relicBonusByStars = [0.0, 0.04, 0.09, 0.15, 0.22, 0.30];

double relicBonus(int stars) => _relicBonusByStars[stars.clamp(0, SummonState.maxStars)];

/// 용화 단계가 주는 곱연산 배수.
double dragonMultiplier(int stage, BalanceConfig c) =>
    pow(c.dragonStageMultiplier, stage).toDouble();
