import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idle_fantasy/data/idle_api_client.dart';

/// 요청을 기록하고 미리 정한 응답을 돌려주는 가짜 HTTP.
class _Recorder {
  final requests = <http.Request>[];
  final responses = <String, http.Response>{};

  http.Client client() => MockClient((req) async {
        requests.add(req);
        final key = '${req.method} ${req.url.path}';
        return responses[key] ?? http.Response('{"detail":"Not Found"}', 404);
      });
}

void main() {
  late _Recorder rec;
  late IdleApiClient api;

  setUp(() {
    rec = _Recorder();
    api = IdleApiClient(rec.client(), baseUrl: 'http://test');
  });

  test('guest: deviceId를 보내고 세션을 받는다', () async {
    rec.responses['POST /auth/guest'] =
        http.Response('{"playerId":7,"accessToken":"tok","created":true}', 200);
    final s = await api.guest('dev-1');
    expect(s.playerId, 7);
    expect(s.accessToken, 'tok');
    expect(jsonDecode(rec.requests.single.body), {'deviceId': 'dev-1'});
    expect(rec.requests.single.headers['content-type'], startsWith('application/json'));
  });

  test('balance: 서버 계수를 BalanceConfig로 받는다', () async {
    rec.responses['GET /masterdata/balance'] = http.Response(jsonEncode({
      'version': 2, 'unchanged': false, 'monsterHpBase': 10, 'monsterHpGrowth': 1.2,
      'bossHpMultiplier': 10, 'bossTimeLimit': 30, 'goldBase': 5, 'goldGrowth': 1.15,
      'bossGoldMultiplier': 10, 'upgradeCostGrowth': 1.09, 'killsPerStage': 10,
      'critMultiplier': 2.0, 'offlineCapSeconds': 28800, 'offlineEfficiency': 0.5, 'offlineMinSeconds': 60,
    }), 200);
    final c = await api.balance();
    expect(c!.version, 2);
    expect(c.monsterHpGrowth, 1.2);
  });

  test('balance: 캐시 버전이 같으면 null (unchanged)', () async {
    rec.responses['GET /masterdata/balance'] = http.Response(
      '{"version":1,"unchanged":true,"monsterHpBase":10,"monsterHpGrowth":1.18,"bossHpMultiplier":10,'
      '"bossTimeLimit":30,"goldBase":5,"goldGrowth":1.15,"bossGoldMultiplier":10,"upgradeCostGrowth":1.09,'
      '"killsPerStage":10,"critMultiplier":2.0,"offlineCapSeconds":28800,"offlineEfficiency":0.5,"offlineMinSeconds":60}',
      200,
    );
    expect(await api.balance(cachedVersion: 1), isNull);
    expect(rec.requests.single.url.queryParameters['version'], '1');
  });

  test('load: Bearer 토큰을 붙이고 보상을 해석한다', () async {
    rec.responses['GET /save'] = http.Response(
      '{"state":{"stage":3},"syncedAt":"2026-09-03T03:00:00Z","created":false,'
      '"offlineReward":{"elapsedSeconds":7200,"gold":123.5}}',
      200,
    );
    final r = await api.load(const GuestSession(playerId: 1, accessToken: 'tok'));
    expect(rec.requests.single.headers['authorization'], 'Bearer tok');
    expect(r.state['stage'], 3);
    expect(r.offlineReward!.elapsed, const Duration(hours: 2));
    expect(r.offlineReward!.gold, 123.5);
  });

  test('load: 보상이 null이면 null', () async {
    rec.responses['GET /save'] =
        http.Response('{"state":{"stage":1},"syncedAt":"2026-09-03T03:00:00Z","created":true,"offlineReward":null}', 200);
    final r = await api.load(const GuestSession(playerId: 1, accessToken: 'tok'));
    expect(r.created, true);
    expect(r.offlineReward, isNull);
  });

  test('sync: 상태를 PUT 하고 거부 규칙을 받는다', () async {
    rec.responses['PUT /save'] =
        http.Response('{"accepted":false,"state":{"stage":1,"gold":30},"syncedAt":"2026-09-03T03:00:00Z","rejectedRule":"gold_conservation"}', 200);
    final r = await api.sync(const GuestSession(playerId: 1, accessToken: 'tok'), {'stage': 1, 'gold': 999});
    expect(jsonDecode(rec.requests.single.body), {'state': {'stage': 1, 'gold': 999}});
    expect(r.accepted, false);
    expect(r.rejectedRule, 'gold_conservation');
    expect(r.state['gold'], 30);
  });

  test('2xx가 아니면 ApiException', () async {
    rec.responses['GET /save'] = http.Response.bytes(utf8.encode('{"detail":"인증이 필요합니다."}'), 401);
    expect(
      () => api.load(const GuestSession(playerId: 1, accessToken: 'bad')),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });
}
