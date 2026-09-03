import 'game_state.dart';
import 'upgrade.dart';

/// 저장 단위. 상태 + 저장 시각.
///
/// 지금은 기기 시각을 쓴다. 5주차에 서버로 옮기면 savedAt은 서버 시간이 된다.
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
    };

GameState? decodeState(Map<String, dynamic> j) {
  try {
    final rawLevels = j['levels'] as Map<String, dynamic>? ?? const {};
    final levels = <UpgradeType, int>{};
    for (final e in rawLevels.entries) {
      final type = UpgradeType.values.asNameMap()[e.key];
      // 모르는 업그레이드는 버린다(구버전 저장과의 호환).
      if (type != null) levels[type] = (e.value as num).toInt();
    }
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
    );
  } on TypeError {
    return null;
  } on NoSuchMethodError {
    return null;
  }
}
