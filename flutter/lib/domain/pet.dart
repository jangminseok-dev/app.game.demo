import 'dart:math';

/// 펫 등급. 알에서 무엇이 나올지는 등급 추첨으로 정한다.
enum PetGrade {
  common('일반', 1.0, 0xFF9AA0A6),
  rare('희귀', 2.0, 0xFF4C9AFF),
  epic('영웅', 3.5, 0xFFB388FF),
  legendary('전설', 6.0, 0xFFFFC24A);

  const PetGrade(this.label, this.multiplier, this.color);

  final String label;

  /// 같은 능력이라도 등급이 높으면 이만큼 세다.
  final double multiplier;
  final int color;
}

/// 펫이 주는 능력 한 가지. 하나만 갖게 해서 무엇을 키울지가 선택이 되게 한다.
enum PetBonus {
  attack('공격력', 0.04),
  gold('골드 획득', 0.05),
  crit('치명타', 0.01);

  const PetBonus(this.label, this.perGrade);

  final String label;

  /// 등급 배수 1.0 기준 증가폭.
  final double perGrade;
}

/// 펫 한 마리. 등급과 능력만 있으면 되고 성장은 하지 않는다.
class Pet {
  const Pet({required this.grade, required this.bonus});

  final PetGrade grade;
  final PetBonus bonus;

  /// 이 펫이 실제로 주는 증가폭.
  double get value => bonus.perGrade * grade.multiplier;

  String get label => '${grade.label} ${bonus.label} 펫';

  Map<String, dynamic> toJson() => {'grade': grade.name, 'bonus': bonus.name};

  static Pet? fromJson(Map<String, dynamic> j) {
    final grade = PetGrade.values.where((g) => g.name == j['grade']).firstOrNull;
    final bonus = PetBonus.values.where((b) => b.name == j['bonus']).firstOrNull;
    if (grade == null || bonus == null) return null;
    return Pet(grade: grade, bonus: bonus);
  }

  @override
  bool operator ==(Object other) => other is Pet && other.grade == grade && other.bonus == bonus;

  @override
  int get hashCode => Object.hash(grade, bonus);
}

/// 가진 펫과 지금 데리고 다니는 펫. 슬롯은 하나다.
///
/// 여러 마리를 동시에 붙이면 어느 펫이 좋은지가 사라진다. 한 마리만 데리고 다니게 해서
/// 부화가 매번 선택이 되게 한다.
class PetState {
  const PetState({this.owned = const [], this.activeIndex});

  static const empty = PetState();

  final List<Pet> owned;

  /// 데리고 다니는 펫의 자리. 없으면 null.
  final int? activeIndex;

  Pet? get active {
    final i = activeIndex;
    return i != null && i >= 0 && i < owned.length ? owned[i] : null;
  }

  double bonusOf(PetBonus bonus) {
    final pet = active;
    return pet != null && pet.bonus == bonus ? pet.value : 0;
  }

  /// 새 펫을 얻는다. 첫 마리는 자동으로 데리고 다닌다.
  PetState add(Pet pet) => PetState(
        owned: [...owned, pet],
        activeIndex: activeIndex ?? owned.length,
      );

  PetState activate(int index) =>
      index >= 0 && index < owned.length ? PetState(owned: owned, activeIndex: index) : this;

  Map<String, dynamic> toJson() => {
        'owned': [for (final p in owned) p.toJson()],
        if (activeIndex != null) 'activeIndex': activeIndex,
      };

  factory PetState.fromJson(Map<String, dynamic> j) => PetState(
        owned: [for (final e in (j['owned'] as List? ?? [])) ?Pet.fromJson(e as Map<String, dynamic>)],
        activeIndex: (j['activeIndex'] as num?)?.toInt(),
      );
}

/// 알에서 나올 펫을 뽑는다. 등급은 알 등급이 좋을수록 유리하다.
Pet rollPet(Random rng, {required double gradeBias}) {
  final r = rng.nextDouble() / gradeBias;
  final grade = r < 0.55
      ? PetGrade.common
      : r < 0.85
          ? PetGrade.rare
          : r < 0.97
              ? PetGrade.epic
              : PetGrade.legendary;
  return Pet(grade: grade, bonus: PetBonus.values[rng.nextInt(PetBonus.values.length)]);
}
