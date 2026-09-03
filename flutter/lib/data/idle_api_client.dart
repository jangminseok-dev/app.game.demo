import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/balance_config.dart';
import '../domain/codex.dart';
import '../domain/offline_reward.dart';
import 'balance_codec.dart';

/// 서버 호출 실패. 네트워크 예외는 `http` 패키지 것이 그대로 올라온다.
class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'ApiException($statusCode): $body';
}

class GuestSession {
  const GuestSession({required this.playerId, required this.accessToken});
  final int playerId;
  final String accessToken;
}

/// 서버 도감 응답 — 성급(0이면 미등록)과 천장 진행.
class RemoteCodex {
  const RemoteCodex({required this.stars, required this.pity});
  final Map<int, int> stars;
  final Map<int, int> pity;

  static const empty = RemoteCodex(stars: {}, pity: {});

  static RemoteCodex parse(List? entries) => RemoteCodex(
        stars: {
          for (final e in entries ?? const [])
            if ((e['stars'] as num).toInt() > 0) (e['monsterId'] as num).toInt(): (e['stars'] as num).toInt(),
        },
        pity: {
          for (final e in entries ?? const [])
            if (((e['pityKills'] as num?) ?? 0).toInt() > 0)
              (e['monsterId'] as num).toInt(): (e['pityKills'] as num).toInt(),
        },
      );
}

class RemoteLoad {
  const RemoteLoad({
    required this.state,
    required this.offlineReward,
    required this.created,
    required this.codex,
  });
  final Map<String, dynamic> state;
  final OfflineReward? offlineReward;
  final bool created;
  final RemoteCodex codex;
}

class RemoteSync {
  const RemoteSync({
    required this.accepted,
    required this.state,
    required this.rejectedRule,
    required this.captures,
    required this.codex,
  });
  final bool accepted;
  final Map<String, dynamic> state;
  final String? rejectedRule;
  final List<CaptureEvent> captures;

  /// 수락 시 갱신 후 도감 전체. 거부 시 null.
  final RemoteCodex? codex;
}

/// 백엔드 API 호출. 경로·JSON 필드는 backend/apps/*/adapter/inbound/api 스키마와 1:1.
class IdleApiClient {
  IdleApiClient(this._http, {required this.baseUrl});

  final http.Client _http;
  final String baseUrl;

  static const _json = {'content-type': 'application/json'};

  Future<GuestSession> guest(String deviceId) async {
    final j = await _post('/auth/guest', body: {'deviceId': deviceId});
    return GuestSession(playerId: j['playerId'] as int, accessToken: j['accessToken'] as String);
  }

  /// 캐시 버전이 같으면 서버가 `unchanged`를 주고, 이때 null을 돌려준다.
  Future<BalanceConfig?> balance({int? cachedVersion}) async {
    final query = cachedVersion == null ? '' : '?version=$cachedVersion';
    final j = await _get('/masterdata/balance$query');
    if (j['unchanged'] == true && cachedVersion != null) return null;
    return balanceFromJson(j);
  }

  /// 몬스터 표(원본 JSON). 캐시 버전이 같으면 null.
  Future<Map<String, dynamic>?> monsters({int? cachedVersion}) async {
    final query = cachedVersion == null ? '' : '?version=$cachedVersion';
    final j = await _get('/masterdata/monsters$query');
    if (j['unchanged'] == true && cachedVersion != null) return null;
    return j;
  }

  Future<RemoteLoad> load(GuestSession s) async {
    final j = await _get('/save', token: s.accessToken);
    final reward = j['offlineReward'] as Map<String, dynamic>?;
    return RemoteLoad(
      state: j['state'] as Map<String, dynamic>,
      created: j['created'] as bool,
      offlineReward: reward == null
          ? null
          : OfflineReward(
              elapsed: Duration(seconds: (reward['elapsedSeconds'] as num).round()),
              gold: (reward['gold'] as num).toDouble(),
            ),
      codex: RemoteCodex.parse(j['codex'] as List?),
    );
  }

  Future<RemoteSync> sync(GuestSession s, Map<String, dynamic> state) async {
    final j = await _put('/save', body: {'state': state}, token: s.accessToken);
    return RemoteSync(
      accepted: j['accepted'] as bool,
      state: j['state'] as Map<String, dynamic>,
      rejectedRule: j['rejectedRule'] as String?,
      captures: [
        for (final c in (j['captures'] as List? ?? const []))
          CaptureEvent(
            monsterId: (c['monsterId'] as num).toInt(),
            stars: (c['stars'] as num).toInt(),
            first: c['first'] as bool,
            byPity: (c['byPity'] as bool?) ?? false,
          ),
      ],
      codex: j['accepted'] == true ? RemoteCodex.parse(j['codex'] as List?) : null,
    );
  }

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    final r = await _http.get(Uri.parse('$baseUrl$path'), headers: _headers(token));
    return _decode(r);
  }

  Future<Map<String, dynamic>> _post(String path, {required Object body, String? token}) async {
    final r = await _http.post(Uri.parse('$baseUrl$path'), headers: _headers(token), body: jsonEncode(body));
    return _decode(r);
  }

  Future<Map<String, dynamic>> _put(String path, {required Object body, String? token}) async {
    final r = await _http.put(Uri.parse('$baseUrl$path'), headers: _headers(token), body: jsonEncode(body));
    return _decode(r);
  }

  Map<String, String> _headers(String? token) =>
      {..._json, if (token != null) 'authorization': 'Bearer $token'};

  Map<String, dynamic> _decode(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) throw ApiException(r.statusCode, r.body);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }
}
