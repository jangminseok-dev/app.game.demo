import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/bootstrap.dart';
import 'app/game_controller.dart';
import 'data/save_repository.dart';
import 'domain/balance_config.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 고정 (GAME_DESIGN 1장)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  const config = BalanceConfig();
  final repo = SharedPrefsSaveRepository(await SharedPreferences.getInstance());
  final boot = await Bootstrap.load(repo, config, DateTime.now());

  runApp(
    ProviderScope(
      overrides: [
        balanceConfigProvider.overrideWithValue(config),
        saveRepositoryProvider.overrideWithValue(repo),
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
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const GameScreen(),
    );
  }
}
