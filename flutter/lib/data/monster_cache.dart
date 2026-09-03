import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/monster.dart';

/// 몬스터 표의 로컬 캐시. 서버 → 캐시 → 번들 에셋(`assets/monsters.json`) 순으로 폴백한다.
class MonsterCache {
  MonsterCache(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'monsters';

  MonsterCatalog? read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return MonsterCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> json) => _prefs.setString(_key, jsonEncode(json));

  /// 앱에 번들된 사본. 서버 `resources/monsters.json`과 같은 파일이다(테스트로 묶여 있다).
  static Future<MonsterCatalog> bundled() async {
    final raw = await rootBundle.loadString('assets/monsters.json');
    return MonsterCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
