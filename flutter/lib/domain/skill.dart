/// 스킬 6종. 이 중 3개만 장착한다.
///
/// 고르는 것이 있어야 스킬서 조각이 재화 구실을 한다. 6종을 다 열어도 3칸이라
/// "무엇을 빼고 무엇을 넣을까"가 남는다(기획: 스킬 풀 6·장착 3).
enum SkillId {
  slash('강타', 6, 4.0, 30, 1),
  pierce('관통', 8, 5.5, 60, 2),
  whirl('회전베기', 10, 7.0, 90, 5),
  bolt('번개', 12, 9.0, 140, 2),
  frost('서리', 14, 11.0, 200, 3),
  meteor('유성', 20, 18.0, 300, 5);

  const SkillId(this.label, this.cooldown, this.damageMultiplier, this.pageCost, this.targets);

  final String label;

  /// 재사용 대기 시간(초).
  final double cooldown;

  /// 평타 대비 피해 배수.
  final double damageMultiplier;

  /// 해금에 드는 스킬서 조각.
  final int pageCost;

  /// 한 번에 때리는 몬스터 수. 무리 전투에서 광역과 단일을 가른다.
  final int targets;

  bool get isAreaOfEffect => targets > 1;
}

/// 해금한 스킬, 장착한 3칸, 각 칸의 남은 대기 시간.
///
/// 스킬은 자동으로 나가고 탭하면 즉시 나간다. 방치형이라 자동이 기본이고
/// 탭은 보스에서 몰아 쓰는 용도다.
class SkillState {
  const SkillState({
    this.unlocked = const {},
    this.equipped = const [null, null, null],
    this.cooldowns = const [0, 0, 0],
    this.auto = const [true, true, true],
  });

  static const empty = SkillState();
  static const slots = 3;

  final Set<SkillId> unlocked;

  /// 칸마다 장착한 스킬. 비었으면 null.
  final List<SkillId?> equipped;

  /// 칸마다 남은 대기 시간(초).
  final List<double> cooldowns;

  /// 칸마다 자동 발동 여부. 끄면 보스에 몰아 쓰려고 아껴 둘 수 있다.
  final List<bool> auto;

  bool isAuto(int slot) => slot >= 0 && slot < slots && auto[slot];

  /// 자동을 켜고 끈다.
  SkillState toggleAuto(int slot) {
    if (slot < 0 || slot >= slots) return this;
    return copyWith(auto: [...auto]..[slot] = !auto[slot]);
  }

  SkillId? at(int slot) => slot >= 0 && slot < slots ? equipped[slot] : null;

  double cooldownAt(int slot) => slot >= 0 && slot < slots ? cooldowns[slot] : 0;

  bool isReady(int slot) => at(slot) != null && cooldownAt(slot) <= 0;

  /// 장착한 것 중 지금 나갈 수 있는 칸.
  Iterable<int> get readySlots => [for (var i = 0; i < slots; i++) if (isReady(i)) i];

  /// 그중 자동이 켜진 칸. 전투 루프가 이 칸만 알아서 쏜다.
  Iterable<int> get autoReadySlots =>
      [for (var i = 0; i < slots; i++) if (isReady(i) && isAuto(i)) i];

  SkillState unlock(SkillId id) => copyWith(unlocked: {...unlocked, id});

  /// 칸에 스킬을 넣는다. 다른 칸에 있던 것이면 두 칸을 맞바꾼다.
  SkillState equip(int slot, SkillId id) {
    if (slot < 0 || slot >= slots || !unlocked.contains(id)) return this;
    final next = [...equipped];
    final previous = next.indexOf(id);
    if (previous >= 0) next[previous] = equipped[slot];
    next[slot] = id;
    return copyWith(equipped: next, cooldowns: _resetCooldown(slot));
  }

  /// 스킬을 쓴다. 대기 시간이 다시 찬다.
  SkillState fire(int slot) {
    final id = at(slot);
    if (id == null) return this;
    final next = [...cooldowns]..[slot] = id.cooldown;
    return copyWith(cooldowns: next);
  }

  /// 시간이 지난 만큼 대기 시간을 줄인다.
  SkillState advance(double seconds) {
    if (cooldowns.every((c) => c <= 0)) return this;
    return copyWith(cooldowns: [for (final c in cooldowns) c <= 0 ? 0 : c - seconds]);
  }

  List<double> _resetCooldown(int slot) => [...cooldowns]..[slot] = 0;

  SkillState copyWith({
    Set<SkillId>? unlocked,
    List<SkillId?>? equipped,
    List<double>? cooldowns,
    List<bool>? auto,
  }) =>
      SkillState(
        unlocked: unlocked ?? this.unlocked,
        equipped: equipped ?? this.equipped,
        cooldowns: cooldowns ?? this.cooldowns,
        auto: auto ?? this.auto,
      );

  Map<String, dynamic> toJson() => {
        'unlocked': [for (final s in unlocked) s.name],
        'equipped': [for (final s in equipped) s?.name],
        'cooldowns': cooldowns,
        'auto': auto,
      };

  factory SkillState.fromJson(Map<String, dynamic> j) {
    SkillId? parse(Object? raw) => SkillId.values.where((s) => s.name == raw).firstOrNull;
    final equipped = j['equipped'] is List ? j['equipped'] as List : const [];
    final cooldowns = j['cooldowns'] is List ? j['cooldowns'] as List : const [];
    final auto = j['auto'] is List ? j['auto'] as List : const [];
    return SkillState(
      unlocked: {for (final e in (j['unlocked'] as List? ?? [])) ?parse(e)},
      equipped: [
        for (var i = 0; i < slots; i++) i < equipped.length ? parse(equipped[i]) : null,
      ],
      cooldowns: [
        for (var i = 0; i < slots; i++)
          i < cooldowns.length ? (cooldowns[i] as num).toDouble() : 0.0,
      ],
      auto: [
        for (var i = 0; i < slots; i++) i >= auto.length || auto[i] == true,
      ],
    );
  }
}

/// 칸이 열리는 층. 해금표(quest.dart)의 스킬 슬롯 줄과 같은 값이어야 한다.
const skillSlotStages = [0, 120, 200];

/// 스킬 칸이 몇 개까지 열려 있는가.
int skillSlotsOpen(int highestStage) =>
    skillSlotStages.where((stage) => highestStage >= stage).length;
