import 'field.dart';

/// 무리 전투에 서 있는 몬스터 한 마리.
///
/// 한 번에 한 마리만 상대하면 스킬 범위도, 무리도 의미가 없다. 여러 마리를 동시에
/// 세워 두고 평타는 앞을 때리고 광역 스킬은 여러 마리를 함께 때린다.
class MonsterUnit {
  const MonsterUnit({
    required this.key,
    required this.id,
    required this.hp,
    required this.maxHp,
    required this.x,
    required this.y,
    this.attackTimer = 0,
  });

  /// 무대가 같은 몬스터를 알아보는 데 쓰는 번호. 소환할 때마다 새로 매긴다.
  final int key;

  /// 마스터 데이터의 몬스터 id.
  final int id;

  final double hp;
  final double maxHp;

  /// 필드 좌표. 주인공을 향해 한꺼번에 움직인다.
  final double x;
  final double y;

  /// 다음 공격까지 남은 시간(초).
  final double attackTimer;

  bool get isDead => hp <= 0;

  double get hpRatio => maxHp <= 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);

  MonsterUnit copyWith({double? hp, double? x, double? y, double? attackTimer}) => MonsterUnit(
        key: key,
        id: id,
        hp: hp ?? this.hp,
        maxHp: maxHp,
        x: x ?? this.x,
        y: y ?? this.y,
        attackTimer: attackTimer ?? this.attackTimer,
      );

  MonsterUnit damaged(double amount) => copyWith(hp: hp - amount);

  Map<String, dynamic> toJson() =>
      {'key': key, 'id': id, 'hp': hp, 'maxHp': maxHp, 'x': x, 'y': y};

  static MonsterUnit? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return MonsterUnit(
      key: (raw['key'] as num).toInt(),
      id: (raw['id'] as num).toInt(),
      hp: (raw['hp'] as num).toDouble(),
      maxHp: (raw['maxHp'] as num).toDouble(),
      x: (raw['x'] as num?)?.toDouble() ?? monsterSpawnX,
      y: (raw['y'] as num?)?.toDouble() ?? heroHomeY,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MonsterUnit &&
      other.key == key &&
      other.id == id &&
      other.hp == hp &&
      other.maxHp == maxHp &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(key, id, hp, maxHp, x, y);
}
