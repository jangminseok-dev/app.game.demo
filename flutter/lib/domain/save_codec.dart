import 'attendance.dart';
import 'daily.dart';
import 'dungeon.dart';
import 'equipment.dart';
import 'field.dart';
import 'game_state.dart';
import 'hatchery.dart';
import 'monster_unit.dart';
import 'pet.dart';
import 'quest.dart';
import 'skill.dart';
import 'spirit.dart';
import 'summon.dart';
import 'upgrade.dart';

/// 저장 단위. 상태 + 저장 시각.
///
/// 로컬 저장은 기기 시각을 쓴다. 서버 세이브의 시각은 서버가 관리한다.
class SaveData {
  const SaveData({required this.state, required this.savedAt});

  final GameState state;
  final DateTime savedAt;

  static const version = 1;

  Map<String, dynamic> toJson() => {
        'version': version,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'state': encodeState(state),
      };

  /// 형식이 맞지 않으면 null. 저장 파일이 깨졌을 때 새 게임으로 시작하기 위함.
  static SaveData? fromJson(Map<String, dynamic> json) {
    if (json['version'] != version) return null;
    final savedAt = DateTime.tryParse(json['savedAt'] as String? ?? '');
    final state = json['state'];
    if (savedAt == null || state is! Map<String, dynamic>) return null;
    final decoded = decodeState(state);
    if (decoded == null) return null;
    return SaveData(state: decoded, savedAt: savedAt.toLocal());
  }
}

/// 서버(`save/domain/snapshot.py`)가 읽는 필드명과 같다. 서버가 모르는 필드(codex·passives)는
/// 로컬 복원용이며 서버 응답의 codex가 항상 우선한다.
Map<String, dynamic> encodeState(GameState s) => {
      'stage': s.stage,
      'highestStage': s.highestStage,
      'gold': s.gold,
      'levels': {for (final e in s.levels.entries) e.key.name: e.value},
      // 서버와 구버전 클라이언트가 읽는 대표값 — 맨 앞 몬스터다.
      'monsterHp': s.monsterHp,
      'monsterMaxHp': s.monsterMaxHp,
      'isBoss': s.isBoss,
      'bossTimeLeft': s.bossTimeLeft,
      'killsOnStage': s.killsOnStage,
      'attackTimer': s.attackTimer,
      'totalKills': s.totalKills,
      'monsterId': s.monsterId,
      'wave': [for (final u in s.wave) u.toJson()],
      'waveSeq': s.waveSeq,
      'heroHp': s.heroHp,
      'heroMp': s.heroMp,
      // 절대 위치는 뜻이 없지만 무리와의 상대 위치는 뜻이 있다 — 0으로 되돌리면 저장된 무리가
      // 절대 좌표에 남아 걷는 시간이 헛되이 생긴다(2026-09-06 전체 리뷰 C1). heroY는 안 담는다 —
      // 걷는 띠 안에서 리셋되는 게 맞다.
      'heroX': s.heroX,
      'stageTimeLeft': s.stageTimeLeft,
      'stageFailCount': s.stageFailCount,
      'killLog': {'normal': _encodeIntMap(s.killLog), 'boss': _encodeIntMap(s.bossKillLog)},
      'codex': _encodeIntMap(s.codex),
      'pity': _encodeIntMap(s.pity),
      'equipment': s.equipment.toJson(),
      'dungeon': s.dungeon.toJson(),
      'quests': s.quests.toJson(),
      'pets': s.pets.toJson(),
      'hatchery': s.hatchery.toJson(),
      'skills': s.skills.toJson(),
      'attendance': s.attendance.toJson(),
      'daily': s.daily.toJson(),
      'summon': s.summon.toJson(),
      'spirits': s.spirits.toJson(),
    };

/// 도감의 패시브는 여기서 복원하지 않는다 — 카탈로그가 필요하므로 호출 측이 [BattleEngine.withCodex]로 채운다.
GameState? decodeState(Map<String, dynamic> j) {
  try {
    final rawLevels = j['levels'] as Map<String, dynamic>? ?? const {};
    final levels = <UpgradeType, int>{};
    for (final e in rawLevels.entries) {
      final type = UpgradeType.values.asNameMap()[e.key];
      // 모르는 업그레이드는 버린다(구버전 저장과의 호환).
      if (type != null) levels[type] = (e.value as num).toInt();
    }
    final killLog = j['killLog'] as Map<String, dynamic>? ?? const {};
    return GameState(
      stage: (j['stage'] as num).toInt(),
      highestStage: (j['highestStage'] as num).toInt(),
      gold: (j['gold'] as num).toDouble(),
      levels: levels,
      wave: _decodeWave(j),
      waveSeq: (j['waveSeq'] as num?)?.toInt() ?? 0,
      // 없으면 -1 — 다음 틱에 최대치로 채워진다.
      heroHp: (j['heroHp'] as num?)?.toDouble() ?? -1,
      heroMp: (j['heroMp'] as num?)?.toDouble() ?? -1,
      // 옛 저장에는 없으니 0 — 그런 저장은 무리도 절대 좌표 없이 기본값으로 다시 서므로 안전하다.
      heroX: (j['heroX'] as num?)?.toDouble() ?? 0,
      stageTimeLeft: (j['stageTimeLeft'] as num?)?.toDouble() ?? -1,
      stageFailCount: (j['stageFailCount'] as num?)?.toInt() ?? 0,
      isBoss: j['isBoss'] as bool,
      bossTimeLeft: (j['bossTimeLeft'] as num).toDouble(),
      killsOnStage: (j['killsOnStage'] as num).toInt(),
      attackTimer: (j['attackTimer'] as num).toDouble(),
      totalKills: (j['totalKills'] as num).toInt(),
      killLog: _decodeIntMap(killLog['normal']),
      bossKillLog: _decodeIntMap(killLog['boss']),
      codex: _decodeIntMap(j['codex']),
      pity: _decodeIntMap(j['pity']),
      equipment: EquipmentState.fromJson(j['equipment'] as Map<String, dynamic>? ?? const {}),
      dungeon: DungeonState.fromJson(j['dungeon'] as Map<String, dynamic>? ?? const {}),
      quests: QuestState.fromJson(j['quests'] as Map<String, dynamic>? ?? const {}),
      pets: PetState.fromJson(j['pets'] as Map<String, dynamic>? ?? const {}),
      hatchery: HatcheryState.fromJson(j['hatchery'] as Map<String, dynamic>? ?? const {}),
      skills: SkillState.fromJson(j['skills'] as Map<String, dynamic>? ?? const {}),
      attendance: AttendanceState.fromJson(j['attendance'] as Map<String, dynamic>? ?? const {}),
      daily: DailyState.fromJson(j['daily'] as Map<String, dynamic>? ?? const {}),
      summon: SummonState.fromJson(j['summon'] as Map<String, dynamic>? ?? const {}),
      spirits: SpiritState.fromJson(j['spirits'] as Map<String, dynamic>? ?? const {}),
    );
  } on TypeError {
    return null;
  } on NoSuchMethodError {
    return null;
  }
}

Map<String, int> _encodeIntMap(Map<int, int> m) => {for (final e in m.entries) '${e.key}': e.value};

Map<int, int> _decodeIntMap(Object? raw) {
  if (raw is! Map) return const {};
  return {for (final e in raw.entries) int.parse('${e.key}'): (e.value as num).toInt()};
}

/// 무리를 읽는다. 무리 전투 이전 저장에는 대표값 하나뿐이라 한 마리로 되살린다.
List<MonsterUnit> _decodeWave(Map<String, dynamic> j) {
  final raw = j['wave'];
  if (raw is List && raw.isNotEmpty) {
    final units = [for (final e in raw) ?MonsterUnit.fromJson(e)];
    if (units.isNotEmpty) return units;
  }
  final hp = (j['monsterHp'] as num?)?.toDouble() ?? 0;
  final maxHp = (j['monsterMaxHp'] as num?)?.toDouble() ?? 0;
  if (maxHp <= 0) return const [];
  return [
    MonsterUnit(
      key: 0,
      id: (j['monsterId'] as num?)?.toInt() ?? 1,
      hp: hp,
      maxHp: maxHp,
      x: spawnAheadOfHero,
      y: heroHomeY,
    ),
  ];
}
