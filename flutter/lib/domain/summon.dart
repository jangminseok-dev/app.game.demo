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

  /// 유물 성급 상한. ★5 뒤는 보정이 완만해져 힘보다 길이를 번다.
  static const maxStars = 10;

  /// 용화 단계 상한. 아트 표가 다섯 단계뿐이다 —
  /// 뿔·꼬리·날개막·비늘, 그리고 눈이 빛나는 것(ART_GUIDE 2절).
  /// 성급 상한과 따로 둔다. 묶으면 상한을 올릴 때 없는 그림을 요구하게 된다.
  static const maxDragonStage = 5;

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
  int get dragonStage => (totalStars ~/ RelicSlot.values.length).clamp(0, maxDragonStage);

  bool canSummon(BalanceConfig c) => stones >= c.summonCost;
  bool canSummonTen(BalanceConfig c) => stones >= c.summonTenCost;

  /// 네 칸이 전부 ★5. 더 뽑아도 오를 것이 없다.
  bool get isMaxed => RelicSlot.values.every((s) => starsOf(s) >= maxStars);

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
/// ★5까지는 가파르고 그 뒤는 완만하다. 깊은 성급은 축의 **길이**를 벌지 힘을 벌지 않는다 —
/// 늘어난 힘이 빨리 오면 장비가 죽는다(스펙 3.4).
const _relicBonusByStars = [0.0, 0.04, 0.09, 0.15, 0.22, 0.30, 0.33, 0.36, 0.38, 0.39, 0.40];

double relicBonus(int stars) => _relicBonusByStars[stars.clamp(0, SummonState.maxStars)];

/// 용화 단계가 주는 곱연산 배수.
double dragonMultiplier(int stage, BalanceConfig c) =>
    pow(c.dragonStageMultiplier, stage).toDouble();

/// 소환 한 건의 결과.
class SummonResult {
  const SummonResult({
    required this.slot,
    required this.stars,
    required this.byPity,
    this.upgraded = false,
  });

  final RelicSlot slot;

  /// 굴려 나온 성급(1~5). 실제로 오른 값은 upgraded와 함께 봐야 한다.
  final int stars;

  /// 천장으로 확정된 것인지.
  final bool byPity;

  /// 이미 갖고 있던 부위라 승급으로 들어갔는지.
  final bool upgraded;
}

/// 성급 확률표. 스펙 8.1과 같아야 한다 — 화면의 `확률 보기`도 이 표를 읽는다.
const relicStarChances = <int, double>{1: 0.60, 2: 0.25, 3: 0.10, 4: 0.04, 5: 0.01};

/// 굴려서 나올 수 있는 최고 성급. **성급 상한과 다르다** —
/// 상한 위쪽은 중복 승급으로만 오른다. 천장도 이 값을 준다.
final maxRolledStars = relicStarChances.keys.reduce(max);

/// 유물 하나를 뽑는다. 부위는 균등, 성급은 표. 천장에 닿았으면 ★5 확정.
SummonResult rollRelic(Random rng, {required bool pityReached}) {
  final slot = RelicSlot.values[rng.nextInt(RelicSlot.values.length)];
  if (pityReached) {
    return SummonResult(slot: slot, stars: maxRolledStars, byPity: true);
  }
  var r = rng.nextDouble();
  for (final entry in relicStarChances.entries) {
    if (r < entry.value) return SummonResult(slot: slot, stars: entry.key, byPity: false);
    r -= entry.value;
  }
  return SummonResult(slot: slot, stars: 1, byPity: false);
}

/// 이미 가진 성급과 나온 성급을 합친다.
///
/// 낮게 나와도 +1은 오른다. 무료 소환이라 뽑는 횟수가 적어서
/// 한 번이라도 버려지면 안 된다(스펙 3.2).
int mergeStars({required int current, required int rolled}) =>
    current == 0 ? rolled : max(current + 1, rolled).clamp(1, SummonState.maxStars);

/// 소환을 count번 굴려 새 상태와 결과 목록을 돌려준다.
///
/// 소환석이 모자라면 아무 일도 안 하고 빈 목록을 돌려준다 — 값을 깎지 않는다.
(SummonState, List<SummonResult>) summonRelics(
  SummonState s,
  Random rng,
  BalanceConfig c, {
  required int count,
}) {
  final cost = count == 1 ? c.summonCost : c.summonTenCost;
  if (s.stones < cost) return (s, const []);

  final relics = {...s.relics};
  final results = <SummonResult>[];
  var pity = s.pityCount;

  for (var i = 0; i < count; i++) {
    pity += 1;
    final rolled = rollRelic(rng, pityReached: pity >= c.summonPity);
    final current = relics[rolled.slot] ?? 0;
    relics[rolled.slot] = mergeStars(current: current, rolled: rolled.stars);
    results.add(SummonResult(
      slot: rolled.slot,
      stars: rolled.stars,
      byPity: rolled.byPity,
      upgraded: current > 0,
    ));
    if (rolled.stars >= maxRolledStars) pity = 0;
  }

  return (s.copyWith(stones: s.stones - cost, relics: relics, pityCount: pity), results);
}
