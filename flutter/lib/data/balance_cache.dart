import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/balance_config.dart';
import 'balance_codec.dart';

/// 서버에서 받은 밸런스 계수의 로컬 캐시. 서버가 안 닿을 때 마지막 값으로 시작한다.
class BalanceCache {
  BalanceCache(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'balance';

  BalanceConfig? read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return balanceFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> write(BalanceConfig c) => _prefs.setString(_key, jsonEncode(balanceToJson(c)));
}
