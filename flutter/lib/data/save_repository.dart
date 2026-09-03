import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/save_codec.dart';

/// 저장소 포트. 지금은 기기 로컬(SharedPreferences), 5주차에 서버 구현이 추가된다.
abstract class SaveRepository {
  Future<SaveData?> load();
  Future<void> save(SaveData data);
}

class SharedPrefsSaveRepository implements SaveRepository {
  SharedPrefsSaveRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'save';

  @override
  Future<SaveData?> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return SaveData.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(SaveData data) =>
      _prefs.setString(_key, jsonEncode(data.toJson()));
}
