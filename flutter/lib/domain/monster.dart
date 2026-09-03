/// 몬스터·지역 마스터 데이터. 서버 `GET /masterdata/monsters`(= `assets/monsters.json`)와 1:1.
///
/// 스테이지 → 몬스터 매핑(`forStage`)은 서버 `MonsterCatalog.monster_for_stage`와 같은 규칙이다.
library;

enum MonsterElement {
  fire('화'),
  water('수'),
  earth('지'),
  wind('풍'),
  neutral('무');

  const MonsterElement(this.label);
  final String label;

  static MonsterElement parse(String s) => MonsterElement.values.firstWhere((e) => e.name == s);
}

enum PassiveKind {
  attack('공격력'),
  gold('골드 획득'),
  attackSpeed('공격속도'),
  crit('치명타'),
  capture('포획률');

  const PassiveKind(this.label);
  final String label;

  static PassiveKind parse(String s) => PassiveKind.values.firstWhere((e) => e.name == s);

  /// 표시용 단위. 치명타만 %p, 나머지는 배율 %.
  String format(double value) => '+${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}%';
}

class Region {
  const Region({
    required this.id,
    required this.name,
    required this.stageFrom,
    required this.stageTo,
    required this.completionKind,
    required this.completionValue,
  });

  final String id;
  final String name;
  final int stageFrom;
  final int? stageTo; // null이면 마지막 지역(무한)
  final PassiveKind completionKind;
  final double completionValue;

  bool contains(int stage) => stage >= stageFrom && (stageTo == null || stage <= stageTo!);
}

class Monster {
  const Monster({
    required this.id,
    required this.name,
    required this.region,
    required this.element,
    required this.rarity,
    required this.passiveKind,
    required this.passivePerStar,
  });

  final int id;
  final String name;
  final String region;
  final MonsterElement element;
  final double rarity;
  final PassiveKind passiveKind;
  final double passivePerStar;
}

class MonsterCatalog {
  const MonsterCatalog({required this.version, required this.regions, required this.monsters});

  static const empty = MonsterCatalog(version: 0, regions: [], monsters: []);

  final int version;
  final List<Region> regions;
  final List<Monster> monsters;

  bool get isEmpty => monsters.isEmpty;

  factory MonsterCatalog.fromJson(Map<String, dynamic> j) => MonsterCatalog(
        version: (j['version'] as num).toInt(),
        regions: [
          for (final r in j['regions'] as List)
            Region(
              id: r['id'] as String,
              name: r['name'] as String,
              stageFrom: (r['stageFrom'] as num).toInt(),
              stageTo: (r['stageTo'] as num?)?.toInt(),
              completionKind: PassiveKind.parse(r['completionBonus']['kind'] as String),
              completionValue: (r['completionBonus']['value'] as num).toDouble(),
            ),
        ],
        monsters: [
          for (final m in j['monsters'] as List)
            Monster(
              id: (m['id'] as num).toInt(),
              name: m['name'] as String,
              region: m['region'] as String,
              element: MonsterElement.parse(m['element'] as String),
              rarity: (m['rarity'] as num).toDouble(),
              passiveKind: PassiveKind.parse(m['passive']['kind'] as String),
              passivePerStar: (m['passive']['perStar'] as num).toDouble(),
            ),
        ],
      );

  Region? regionFor(int stage) {
    if (regions.isEmpty) return null;
    return regions.firstWhere((r) => r.contains(stage), orElse: () => regions.last);
  }

  List<Monster> monstersIn(String regionId) => monsters.where((m) => m.region == regionId).toList();

  /// 스테이지의 몬스터 — 지역 안에서 순환. 카탈로그가 비어 있으면 null.
  Monster? forStage(int stage) {
    final region = regionFor(stage);
    if (region == null) return null;
    final pool = monstersIn(region.id);
    if (pool.isEmpty) return null;
    return pool[(stage - region.stageFrom) % pool.length];
  }

  Monster? byId(int id) {
    for (final m in monsters) {
      if (m.id == id) return m;
    }
    return null;
  }
}
