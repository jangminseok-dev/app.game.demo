import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 게스트 계정의 기기 식별자. 처음 한 번 난수로 만들어 기기에 보관한다.
///
/// 앱을 지우면 사라지고 계정을 잃는다 — 소셜 연동(13주차) 전까지의 한계다.
class DeviceIdentity {
  DeviceIdentity(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'device_id';

  Future<String> getOrCreate() async {
    final existing = _prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random.secure();
    final id = List.generate(32, (_) => rng.nextInt(16).toRadixString(16)).join();
    await _prefs.setString(_key, id);
    return id;
  }
}
