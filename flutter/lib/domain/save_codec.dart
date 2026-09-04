import 'equipment.dart';
import 'game_state.dart';
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
      'monsterHp': s.monsterHp,
      'monsterMaxHp': s.monsterMaxHp,
      'isBoss': s.isBoss,
      'bossTimeLeft': s.bossTimeLeft,
      'killsOnStage': s.killsOnStage,
      'attackTimer': s.attackTimer,
      'totalKills': s.totalKills,
      'monsterId': s.monsterId,
      'killLog': {'normal': _encodeIntMap(s.killLog), 'boss': _encodeIntMap(s.bossKillLog)},
      'codex': _encodeIntMap(s.codex),
      'pity': _encodeIntMap(s.pity),
      'equipment': s.equipment.toJson(),
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
      monsterHp: (j['monsterHp'] as num).toDouble(),
      monsterMaxHp: (j['monsterMaxHp'] as num).toDouble(),
      isBoss: j['isBoss'] as bool,
      bossTimeLeft: (j['bossTimeLeft'] as num).toDouble(),
      killsOnStage: (j['killsOnStage'] as num).toInt(),
      attackTimer: (j['attackTimer'] as num).toDouble(),
      totalKills: (j['totalKills'] as num).toInt(),
      monsterId: (j['monsterId'] as num?)?.toInt() ?? 1,
      killLog: _decodeIntMap(killLog['normal']),
      bossKillLog: _decodeIntMap(killLog['boss']),
      codex: _decodeIntMap(j['codex']),
      pity: _decodeIntMap(j['pity']),
      equipment: EquipmentState.fromJson(j['equipment'] as Map<String, dynamic>? ?? const {}),
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
