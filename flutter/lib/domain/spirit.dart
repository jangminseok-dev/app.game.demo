import 'balance_config.dart';

/// 정령이 하는 일. 넷이 서로 달라야 고를 이유가 생긴다.
enum SpiritEffect {
  /// 전체를 때리고 주인공을 회복시킨다.
  healAll,

  /// 하나만 아주 세게 때린다.
  singleBig,

  /// 전체를 때리고 화상을 남긴다.
  burnAll,

  /// 전체를 때리고 몬스터를 둔하게 만든다.
  slowAll,
}

/// 정령 4종 — 잠든 용이 꾸는 꿈의 조각이다(스펙 4.1).
///
/// 색은 그 꿈이 나온 지역의 팔레트를 따른다(GAME_DESIGN 18.3).
/// 반투명 발광체라 6색 규격 밖이다 — 이펙트 취급이다.
enum SpiritId {
  moss('이끼의 꿈', 0xFF8FBF5A, SpiritEffect.healAll),
  crystal('수정의 꿈', 0xFF4FD0C0, SpiritEffect.singleBig),
  ember('잿불의 꿈', 0xFFE0713A, SpiritEffect.burnAll),
  frost('서리의 꿈', 0xFF7FC4FF, SpiritEffect.slowAll);

  const SpiritId(this.label, this.color, this.effect);

  final String label;

  /// 지역 색. 컷신과 화면이 이 값을 쓴다.
  final int color;

  final SpiritEffect effect;
}

/// 가진 정령과 데리고 다니는 하나, 그리고 게이지.
///
/// 유물과 달리 **칸이 하나**다. 그래서 성급 상한이 ★5다 —
/// ★10까지 열면 한 마리에 몰아 넣는 것이 언제나 정답이 되어 4종을 만든 뜻이 사라진다.
class SpiritState {
  const SpiritState({
    this.owned = const {},
    this.active,
    this.gauge = 0,
    this.firedCount = 0,
    this.burnLeft = 0,
    this.slowLeft = 0,
    this.pityCount = 0,
  });

  static const empty = SpiritState();

  /// 정령 성급 상한. 유물(★10)과 다르다 — 위 주석 참조.
  /// 유물과 달리 상한이 확률표 꼭대기와 같다 — 천장 한 번이 곧 만렙 한 칸이다.
  static const maxStars = 5;

  /// 종류 → 성급(1~5). 없는 종류는 키가 없다.
  final Map<SpiritId, int> owned;

  /// 데리고 다니는 하나. 없으면 null.
  final SpiritId? active;

  /// 0~1. 1이 되면 나온다.
  final double gauge;

  /// 지금까지 나온 횟수. **화면이 이 값이 오르는 것을 보고 컷신을 띄운다.**
  /// 불 하나(bool)로 두면 같은 프레임에 두 번 오르거나 화면이 놓친다.
  final int firedCount;

  /// 화상이 남은 초. 저장하지 않는다 — 전투가 끝나면 사라지는 것이다.
  /// 무리가 아니라 전투 전체에 걸린다 — 무리가 바뀌어도 남은 시간 동안 이어진다.
  final double burnLeft;

  /// 둔화가 남은 초. 저장하지 않는다.
  /// 무리가 아니라 전투 전체에 걸린다 — 무리가 바뀌어도 남은 시간 동안 이어진다.
  final double slowLeft;

  /// ★5 없이 뽑은 횟수. 천장에 닿으면 다음 한 번이 확정이다.
  ///
  /// **유물과 따로 센다**(스펙 8.2) — 한쪽만 뽑는 사람이 손해 보지 않는다.
  final int pityCount;

  int starsOf(SpiritId id) => owned[id] ?? 0;

  int get activeStars => active == null ? 0 : starsOf(active!);

  /// 게이지가 다 찼고 데리고 다니는 정령이 있다.
  bool get isReady => gauge >= 1 && active != null && activeStars > 0;

  /// 4종이 전부 상한. 더 뽑아도 오를 것이 없다.
  bool get isMaxed => SpiritId.values.every((s) => starsOf(s) >= maxStars);

  /// **`active`는 null로 되돌릴 수 없다**(`active ?? this.active`).
  /// 편성을 비우는 기능은 이 계획에 없으므로 그대로 둔다 — 필요해지면 그때 `Object?` 센티널을 쓴다.
  SpiritState copyWith({
    Map<SpiritId, int>? owned,
    SpiritId? active,
    double? gauge,
    int? firedCount,
    double? burnLeft,
    double? slowLeft,
    int? pityCount,
  }) =>
      SpiritState(
        owned: owned ?? this.owned,
        active: active ?? this.active,
        gauge: gauge ?? this.gauge,
        firedCount: firedCount ?? this.firedCount,
        burnLeft: burnLeft ?? this.burnLeft,
        slowLeft: slowLeft ?? this.slowLeft,
        pityCount: pityCount ?? this.pityCount,
      );

  Map<String, dynamic> toJson() => {
        'owned': {for (final e in owned.entries) e.key.name: e.value},
        'active': active?.name,
        'gauge': gauge,
        'firedCount': firedCount,
        'pityCount': pityCount,
      };

  factory SpiritState.fromJson(Map<String, dynamic> j) {
    final raw = j['owned'] as Map<String, dynamic>? ?? const {};
    final activeName = j['active'] as String?;
    return SpiritState(
      owned: {
        for (final id in SpiritId.values)
          if (raw[id.name] != null) id: (raw[id.name] as num).toInt(),
      },
      active: SpiritId.values.where((i) => i.name == activeName).firstOrNull,
      gauge: (j['gauge'] as num? ?? 0).toDouble(),
      firedCount: (j['firedCount'] as num? ?? 0).toInt(),
      pityCount: (j['pityCount'] as num? ?? 0).toInt(),
    );
  }
}

/// 정령이 나올 때의 피해 배수(평타 대비). 성급 0이면 0이다.
double spiritDamageMultiplier(int stars, BalanceConfig c) =>
    stars <= 0 ? 0 : c.spiritDamageBase + c.spiritDamagePerStar * (stars - 1);

/// 평소 공격력 보정(0~0.10).
double spiritPassive(int stars, BalanceConfig c) =>
    stars <= 0 ? 0 : c.spiritPassivePerStar * stars;
