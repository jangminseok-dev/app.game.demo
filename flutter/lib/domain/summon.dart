import 'dart:math';

import 'balance_config.dart';
import 'spirit.dart';

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

  /// 부위 → 성급(1~maxStars). 없는 부위는 키가 없다.
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

  /// 네 칸이 전부 상한. 더 뽑아도 오를 것이 없다.
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

/// 유물 하나가 주는 보정(0~0.40).
/// ★5까지는 가파르고 그 뒤는 완만하다.
///
/// **곡선이 힘을 억제하는 것이 아니다.** ★10까지 열면 축의 천장이 ×2.91에서 ×3.62로 오른다.
/// 억제하는 것은 **공급**이다 — 거기 닿는 데 소환 49회가 들고 진행 보상만으로는 23회뿐이다.
/// 공급을 늘릴 때(광고 등) 이 사실을 잊으면 유물이 장비를 이긴다(스펙 3.4).
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
    this.before = 0,
    this.after = 0,
  });

  final RelicSlot slot;

  /// 굴려 나온 성급(1~maxRolledStars). 실제로 오른 값은 [after] 다.
  final int stars;

  /// 천장으로 확정된 것인지.
  final bool byPity;

  /// 이 소환 **전** 그 부위의 성급. 0이면 처음 나온 부위다.
  ///
  /// [rollRelic] 은 굴리기만 하므로 이 값을 안 채운다. 채우는 곳은 [summonRelics] 하나다.
  final int before;

  /// 승급까지 끝난 **뒤**의 성급. 화면은 이 값을 보여 준다.
  final int after;

  /// 이미 갖고 있던 부위라 승급으로 들어갔는지.
  ///
  /// 상한에 닿은 부위는 upgraded가 참이어도 성급이 안 오른다. 화면 문구는 after > before로 판단한다.
  bool get upgraded => before > 0;

  /// 연출이 그릴 한 줄.
  SummonLine get line => SummonLine(label: slot.label, before: before, after: after);
}

/// 연출이 그리는 한 줄. 유물과 정령이 같은 모양으로 넘긴다.
///
/// 연출은 무엇을 뽑았는지 몰라도 된다 — 이름과 성급 전후만 있으면 그린다.
class SummonLine {
  const SummonLine({required this.label, required this.before, required this.after});

  final String label;
  final int before;
  final int after;

  /// 이미 갖고 있던 것이었나. **상한에 닿으면 참이어도 성급이 안 오른다** —
  /// 문구는 [text] 가 `after > before` 로 판단한다.
  bool get upgraded => before > 0;

  String get text =>
      upgraded && after > before ? '$label ★$before → ★$after' : '$label ★$after';
}

/// 성급 확률표. 스펙 8.1과 같아야 한다 — 화면의 `확률 보기`도 이 표를 읽는다.
const relicStarChances = <int, double>{1: 0.60, 2: 0.25, 3: 0.10, 4: 0.04, 5: 0.01};

/// 굴려서 나올 수 있는 최고 성급. **성급 상한과 다르다** —
/// 상한 위쪽은 중복 승급으로만 오른다. 천장도 이 값을 준다.
final maxRolledStars = relicStarChances.keys.reduce(max);

/// 표를 따라 성급 하나를 굴린다. 천장은 호출부가 처리한다.
int _rollStars(Random rng) {
  var r = rng.nextDouble();
  for (final entry in relicStarChances.entries) {
    if (r < entry.value) return entry.key;
    r -= entry.value;
  }
  return 1;
}

/// 유물 하나를 뽑는다. 부위는 균등, 성급은 표. 천장에 닿았으면 ★5 확정.
SummonResult rollRelic(Random rng, {required bool pityReached}) {
  final slot = RelicSlot.values[rng.nextInt(RelicSlot.values.length)];
  if (pityReached) {
    return SummonResult(slot: slot, stars: maxRolledStars, byPity: true);
  }
  return SummonResult(slot: slot, stars: _rollStars(rng), byPity: false);
}

/// 이미 가진 성급과 나온 성급을 합친다.
///
/// 낮게 나와도 +1은 오른다. 무료 소환이라 뽑는 횟수가 적어서
/// 한 번이라도 버려지면 안 된다(스펙 3.2). `cap`은 유물(★10)과 정령(★5)이 다르다.
int mergeStars({required int current, required int rolled, int cap = SummonState.maxStars}) =>
    current == 0 ? rolled : max(current + 1, rolled).clamp(1, cap);

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
    final merged = mergeStars(current: current, rolled: rolled.stars);
    relics[rolled.slot] = merged;
    results.add(SummonResult(
      slot: rolled.slot,
      stars: rolled.stars,
      byPity: rolled.byPity,
      before: current,
      after: merged,
    ));
    if (rolled.stars >= maxRolledStars) pity = 0;
  }

  return (s.copyWith(stones: s.stones - cost, relics: relics, pityCount: pity), results);
}

/// 결과 한 줄. 승급이면 어디서 어디로 갔는지 보여 준다.
///
/// 굴린 값을 보여 주면 뿔 ★4에 ★1이 나왔을 때 화면이 `뿔 ★1`이라 말한다 —
/// 실제로는 ★5가 되는데도. "헛도는 소환이 없다"는 이 시스템의 약속(1절·10절)이
/// 화면에서 한 번도 안 보이던 자리다.
String summonResultLine(SummonResult r) => r.line.text;

/// 정령 소환 한 건의 결과.
class SpiritSummonResult {
  const SpiritSummonResult({
    required this.id,
    required this.stars,
    required this.byPity,
    this.before = 0,
    this.after = 0,
  });

  final SpiritId id;

  /// 굴려 나온 성급. 실제로 오른 값은 [after] 다.
  final int stars;

  final bool byPity;
  final int before;
  final int after;

  SummonLine get line => SummonLine(label: id.label, before: before, after: after);
}

/// 정령을 count번 소환한다. 소환석은 유물과 같은 지갑에서 나간다(스펙 5.1).
///
/// 확률표는 유물과 같다(스펙 8.1) — 종류 균등, 성급은 [relicStarChances].
/// 천장 카운터도 소환석과 함께 [SummonState] 에 있으므로 유물과 공유한다.
(SummonState, SpiritState, List<SpiritSummonResult>) summonSpirits(
  SummonState stones,
  SpiritState spirits,
  Random rng,
  BalanceConfig c, {
  required int count,
}) {
  final cost = count == 1 ? c.summonCost : c.summonTenCost;
  if (stones.stones < cost) return (stones, spirits, const []);

  final owned = {...spirits.owned};
  final results = <SpiritSummonResult>[];
  var pity = stones.pityCount;

  for (var i = 0; i < count; i++) {
    pity += 1;
    final pityReached = pity >= c.summonPity;
    final id = SpiritId.values[rng.nextInt(SpiritId.values.length)];
    final rolled = pityReached ? maxRolledStars : _rollStars(rng);
    if (rolled >= maxRolledStars) pity = 0;

    final current = owned[id] ?? 0;
    final merged = mergeStars(current: current, rolled: rolled, cap: SpiritState.maxStars);
    owned[id] = merged;
    results.add(SpiritSummonResult(
        id: id, stars: rolled, byPity: pityReached, before: current, after: merged));
  }

  return (
    stones.copyWith(stones: stones.stones - cost, pityCount: pity),
    spirits.copyWith(owned: owned),
    results,
  );
}
