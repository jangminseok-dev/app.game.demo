import 'dart:math';

import 'balance_config.dart';

/// 장비 부위. 화면에 보이는 3부위와 스탯 전용 3부위로 나눈다.
///
/// 레퍼런스(99강화 나무몽둥이)가 10부위 중 3부위만 외형에 반영한 구조를 따른다.
/// 스프라이트를 부위마다 그릴 필요가 없어 1인 개발에서 아트 비용이 크게 줄어든다.
enum EquipSlot {
  weapon('무기', visible: true),
  helmet('투구', visible: true),
  cape('망토', visible: true),
  armor('갑옷'),
  ring('반지'),
  amulet('목걸이');

  const EquipSlot(this.label, {this.visible = false});

  final String label;

  /// true면 캐릭터 스프라이트에 반영되는 부위(추후 아트 작업 대상).
  final bool visible;
}

/// 장비 등급. 등급이 오를수록 기본 배율이 커진다.
///
/// 레퍼런스는 11단계지만 조사에서 "등급은 5~6단계로 압축"이 결론이었다(시장 분석 2.4절).
enum EquipGrade {
  common('일반', 1.0, 0xFF9AA0A6),
  uncommon('고급', 1.6, 0xFF56D364),
  rare('희귀', 2.6, 0xFF4C9AFF),
  epic('영웅', 4.2, 0xFFB388FF),
  legendary('전설', 7.0, 0xFFFFC24A);

  const EquipGrade(this.label, this.multiplier, this.color);

  final String label;

  /// 같은 부위 안에서 등급이 주는 기본 배율.
  final double multiplier;
  final int color;
}

/// 장비 한 점. 마스터 데이터가 아니라 드롭으로 생성되는 인스턴스다.
///
/// 강화 수치는 장비가 아니라 캐릭터에 붙는다([EquipmentState.enhanceLevel]).
/// 레퍼런스의 "모든 장비가 강화 단계를 공유" 설계로, 좋은 장비가 떠도 강화값이 아깝지 않다.
class Equipment {
  const Equipment({required this.slot, required this.grade, required this.tier});

  final EquipSlot slot;
  final EquipGrade grade;

  /// 드롭된 층 구간(1티어 = 1~50층). 층이 깊을수록 기본값이 커진다.
  final int tier;

  /// 이 장비가 주는 공격력 배수 기여분.
  double get power => grade.multiplier * (1 + tier * 0.35);

  /// 분해했을 때 나오는 강화석.
  int get scrapValue => (grade.index + 1) * (1 + tier);

  String get label => '${grade.label} ${slot.label}';

  Map<String, dynamic> toJson() => {'slot': slot.name, 'grade': grade.name, 'tier': tier};

  static Equipment? fromJson(Map<String, dynamic> j) {
    final slot = EquipSlot.values.where((s) => s.name == j['slot']).firstOrNull;
    final grade = EquipGrade.values.where((g) => g.name == j['grade']).firstOrNull;
    if (slot == null || grade == null) return null;
    return Equipment(slot: slot, grade: grade, tier: (j['tier'] as num).toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is Equipment && other.slot == slot && other.grade == grade && other.tier == tier;

  @override
  int get hashCode => Object.hash(slot, grade, tier);
}

/// 장비·강화석·강화 레벨을 묶은 상태. [GameState]가 이 하나만 들고 있으면 된다.
class EquipmentState {
  const EquipmentState({
    this.equipped = const {},
    this.inventory = const [],
    this.stones = 0,
    this.enhanceLevel = 0,
  });

  static const empty = EquipmentState();

  /// 부위별 착용 중인 장비.
  final Map<EquipSlot, Equipment> equipped;

  /// 아직 착용하지 않은 장비. 분해 대상.
  final List<Equipment> inventory;

  /// 분해로 얻는 재화. 강화에만 쓴다(재화 1종 = 소비처 1종).
  final int stones;

  /// 캐릭터 귀속 강화 레벨. 파괴·하락 없이 무한히 오른다.
  final int enhanceLevel;

  /// 장비가 주는 공격력 배수. 착용분 합계 + 강화 레벨.
  ///
  /// 계수가 크면 기획서 4장의 "벽" 원칙(보상 성장 1.15 < 요구 성장 1.18)이 깨진다.
  /// 수치는 마스터 데이터([BalanceConfig])에만 두고 여기서는 식만 정한다.
  /// `wall_simulation_test`가 이 균형을 지킨다.
  double powerWith(BalanceConfig c) {
    final gear = equipped.values.fold(0.0, (sum, e) => sum + e.power);
    return 1 + gear * c.equipGearCoefficient + enhanceLevel * c.equipEnhancePerLevel;
  }

  /// 다음 강화에 드는 강화석. 레벨에 따라 완만히 오른다.
  int get enhanceCost => 5 + enhanceLevel * 3 + (enhanceLevel * enhanceLevel) ~/ 12;

  bool get canEnhance => stones >= enhanceCost;

  /// 새 장비를 얻는다. 같은 부위에 더 센 게 없으면 자동 착용, 있으면 인벤토리로.
  EquipmentState pickUp(Equipment item) {
    final current = equipped[item.slot];
    if (current == null || item.power > current.power) {
      return copyWith(
        equipped: {...equipped, item.slot: item},
        inventory: current == null ? inventory : [...inventory, current],
      );
    }
    return copyWith(inventory: [...inventory, item]);
  }

  /// 가방에서 부위마다 가장 센 것을 골라 입는다. 밀린 것은 가방으로 돌아온다.
  ///
  /// 부위가 여섯이라 손으로 갈아입히면 매번 여섯 번을 눌러야 한다.
  /// 레퍼런스도 인벤토리 아래에 `자동 장착`을 둔다.
  EquipmentState autoEquip() {
    final next = {...equipped};
    final pool = [...inventory];
    final removed = <Equipment>[];
    for (final slot in EquipSlot.values) {
      final candidates = pool.where((e) => e.slot == slot).toList()
        ..sort((a, b) => b.power.compareTo(a.power));
      if (candidates.isEmpty) continue;
      final best = candidates.first;
      final current = next[slot];
      if (current != null && current.power >= best.power) continue;
      next[slot] = best;
      pool.remove(best);
      if (current != null) removed.add(current);
    }
    if (removed.isEmpty && next.length == equipped.length) return this;
    return copyWith(equipped: next, inventory: [...pool, ...removed]);
  }

  /// 가방의 [index]번을 입는다. 입고 있던 것은 가방으로 간다.
  EquipmentState equipAt(int index) {
    if (index < 0 || index >= inventory.length) return this;
    final item = inventory[index];
    final current = equipped[item.slot];
    final rest = [...inventory]..removeAt(index);
    return copyWith(
      equipped: {...equipped, item.slot: item},
      inventory: current == null ? rest : [...rest, current],
    );
  }

  /// 가방의 [index]번 하나만 분해한다.
  EquipmentState scrapAt(int index) {
    if (index < 0 || index >= inventory.length) return this;
    final item = inventory[index];
    return copyWith(inventory: [...inventory]..removeAt(index), stones: stones + item.scrapValue);
  }

  /// 인벤토리를 전부 분해해 강화석으로 바꾼다. 착용 중인 것은 건드리지 않는다.
  EquipmentState scrapAll() {
    if (inventory.isEmpty) return this;
    final gained = inventory.fold(0, (sum, e) => sum + e.scrapValue);
    return copyWith(inventory: const [], stones: stones + gained);
  }

  /// 강화석이 충분하면 한 단계 올린다. 실패도 파괴도 없다.
  EquipmentState enhance() =>
      canEnhance ? copyWith(stones: stones - enhanceCost, enhanceLevel: enhanceLevel + 1) : this;

  EquipmentState copyWith({
    Map<EquipSlot, Equipment>? equipped,
    List<Equipment>? inventory,
    int? stones,
    int? enhanceLevel,
  }) {
    return EquipmentState(
      equipped: equipped ?? this.equipped,
      inventory: inventory ?? this.inventory,
      stones: stones ?? this.stones,
      enhanceLevel: enhanceLevel ?? this.enhanceLevel,
    );
  }

  Map<String, dynamic> toJson() => {
        'equipped': {for (final e in equipped.entries) e.key.name: e.value.toJson()},
        'inventory': [for (final e in inventory) e.toJson()],
        'stones': stones,
        'enhanceLevel': enhanceLevel,
      };

  factory EquipmentState.fromJson(Map<String, dynamic> j) {
    final equipped = <EquipSlot, Equipment>{};
    for (final e in (j['equipped'] as Map<String, dynamic>? ?? {}).entries) {
      final slot = EquipSlot.values.where((s) => s.name == e.key).firstOrNull;
      final item = Equipment.fromJson(e.value as Map<String, dynamic>);
      if (slot != null && item != null) equipped[slot] = item;
    }
    return EquipmentState(
      equipped: equipped,
      inventory: [
        for (final e in (j['inventory'] as List? ?? [])) ?Equipment.fromJson(e as Map<String, dynamic>),
      ],
      stones: (j['stones'] as num? ?? 0).toInt(),
      enhanceLevel: (j['enhanceLevel'] as num? ?? 0).toInt(),
    );
  }
}

/// 드롭 판정. 층과 보스 여부로 확률·등급을 정한다.
///
/// 보스는 부위가 고정이다 — "이 보스를 왜 도는가"가 자명해진다(메이플 키우기 방식, 시장 분석 2.1절).
class DropTable {
  const DropTable(this.config);

  final BalanceConfig config;

  /// 층 → 티어. 마스터 데이터의 [BalanceConfig.equipStagesPerTier] 층마다 한 단계.
  int tierOf(int stage) => (stage - 1) ~/ config.equipStagesPerTier;

  /// 보스가 담당하는 부위 — 티어마다 고정된다.
  EquipSlot bossSlotFor(int stage) => EquipSlot.values[tierOf(stage) % EquipSlot.values.length];

  /// 처치 한 번의 드롭. 없으면 null.
  Equipment? roll(int stage, {required bool isBoss, required Random rng}) {
    final chance = isBoss ? config.equipBossDropChance : config.equipFieldDropChance;
    if (rng.nextDouble() >= chance) return null;
    final tier = tierOf(stage);
    return Equipment(
      slot: isBoss ? bossSlotFor(stage) : EquipSlot.values[rng.nextInt(EquipSlot.values.length)],
      grade: _rollGrade(rng, boss: isBoss),
      tier: tier,
    );
  }

  /// 등급 추첨. 보스는 한 단계 유리하다.
  EquipGrade _rollGrade(Random rng, {required bool boss}) {
    final r = rng.nextDouble() * (boss ? 0.72 : 1.0);
    if (r < 0.52) return EquipGrade.common;
    if (r < 0.80) return EquipGrade.uncommon;
    if (r < 0.94) return EquipGrade.rare;
    if (r < 0.99) return EquipGrade.epic;
    return EquipGrade.legendary;
  }
}
