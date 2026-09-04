import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app/bootstrap.dart';
import 'app/game_controller.dart';
import 'data/balance_cache.dart';
import 'data/cloud_save_gateway.dart';
import 'data/device_identity.dart';
import 'data/idle_api_client.dart';
import 'data/monster_cache.dart';
import 'data/save_repository.dart';
import 'domain/balance_config.dart';
import 'domain/monster.dart';
import 'ui/game_screen.dart';
import 'ui/hud/pixel_ui.dart';

/// `flutter run --dart-define=API_BASE_URL=http://...` 로 바꾼다. 기본은 맥 로컬 백엔드.
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8010');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 고정 (GAME_DESIGN 1장)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final local = SharedPrefsSaveRepository(prefs);
  final balanceCache = BalanceCache(prefs);
  final monsterCache = MonsterCache(prefs);
  final api = IdleApiClient(http.Client(), baseUrl: _apiBaseUrl);

  // 서버 연결: 게스트 로그인 → 마스터 데이터(밸런스·몬스터). 실패하면 캐시/내장값 + 로컬 저장으로 간다.
  var config = balanceCache.read() ?? const BalanceConfig();
  var catalog = monsterCache.read() ?? await MonsterCache.bundled();
  CloudSaveGateway? cloud;
  try {
    final session = await api.guest(await DeviceIdentity(prefs).getOrCreate());
    final freshBalance = await api.balance(cachedVersion: balanceCache.read()?.version);
    if (freshBalance != null) {
      config = freshBalance;
      await balanceCache.write(freshBalance);
    }
    final freshMonsters = await api.monsters(cachedVersion: monsterCache.read()?.version);
    if (freshMonsters != null) {
      catalog = MonsterCatalog.fromJson(freshMonsters);
      await monsterCache.write(freshMonsters);
    }
    cloud = ApiCloudSaveGateway(api, session);
  } on Object catch (e) {
    debugPrint('서버 연결 실패 — 로컬 저장으로 시작합니다: $e');
    cloud = null;
  }

  final boot = await Bootstrap.load(
    local: local, cloud: cloud, config: config, now: DateTime.now(), catalog: catalog,
  );

  runApp(
    ProviderScope(
      overrides: [
        balanceConfigProvider.overrideWithValue(config),
        monsterCatalogProvider.overrideWithValue(catalog),
        saveRepositoryProvider.overrideWithValue(local),
        cloudSaveProvider.overrideWithValue(cloud),
        initialStateProvider.overrideWithValue(boot.state),
        offlineRewardProvider.overrideWithValue(boot.offlineReward),
      ],
      child: const IdleFantasyApp(),
    ),
  );
}

class IdleFantasyApp extends StatelessWidget {
  const IdleFantasyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idle Fantasy',
      // 픽셀 무대 위에 시스템 폰트가 섞이면 화면 절반이 설정 화면처럼 보인다.
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFB57A17),
        useMaterial3: true,
        fontFamily: pixelFont,
        scaffoldBackgroundColor: const Color(0xFF12161A),
      ),
      home: const GameScreen(),
    );
  }
}
