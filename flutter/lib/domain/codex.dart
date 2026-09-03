import 'monster.dart';

/// 도감 패시브 합계(%). 종류 안에서는 합연산(GAME_DESIGN 7장 1번), 종류 간에는 곱.
/// 서버 `codex/domain/passives.py`와 같은 규칙이다.
class Passives {
  const Passives({
    this.attack = 0,
    this.gold = 0,
    this.attackSpeed = 0,
    this.crit = 0,
    this.capture = 0,
  });

  static const none = Passives();

  final double attack;
  final double gold;
  final double attackSpeed;
  final double crit; // %p
  final double capture;

  bool get isEmpty => attack == 0 && gold == 0 && attackSpeed == 0 && crit == 0 && capture == 0;

  double of(PassiveKind kind) => switch (kind) {
        PassiveKind.attack => attack,
        PassiveKind.gold => gold,
        PassiveKind.attackSpeed => attackSpeed,
        PassiveKind.crit => crit,
        PassiveKind.capture => capture,
      };
}

/// 서버가 동기화 응답으로 돌려주는 포획 이벤트.
class CaptureEvent {
  const CaptureEvent({required this.monsterId, required this.stars, required this.first});
  final int monsterId;
  final int stars;
  final bool first;
}

/// 도감(몬스터 id → 성급)에서 패시브 합계를 구한다.
Passives computePassives(Map<int, int> codex, MonsterCatalog catalog) {
  if (codex.isEmpty || catalog.isEmpty) return Passives.none;
  final totals = <PassiveKind, double>{for (final k in PassiveKind.values) k: 0};
  for (final m in catalog.monsters) {
    final stars = codex[m.id] ?? 0;
    if (stars > 0) totals[m.passiveKind] = totals[m.passiveKind]! + m.passivePerStar * stars;
  }
  for (final r in catalog.regions) {
    final pool = catalog.monstersIn(r.id);
    if (pool.isNotEmpty && pool.every((m) => (codex[m.id] ?? 0) > 0)) {
      totals[r.completionKind] = totals[r.completionKind]! + r.completionValue;
    }
  }
  return Passives(
    attack: totals[PassiveKind.attack]!,
    gold: totals[PassiveKind.gold]!,
    attackSpeed: totals[PassiveKind.attackSpeed]!,
    crit: totals[PassiveKind.crit]!,
    capture: totals[PassiveKind.capture]!,
  );
}

/// 지역별 (등록 수, 전체 수).
Map<String, (int, int)> regionCompletion(Map<int, int> codex, MonsterCatalog catalog) => {
      for (final r in catalog.regions)
        r.id: (
          catalog.monstersIn(r.id).where((m) => (codex[m.id] ?? 0) > 0).length,
          catalog.monstersIn(r.id).length,
        ),
    };
