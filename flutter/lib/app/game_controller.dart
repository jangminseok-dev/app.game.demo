import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/save_repository.dart';
import '../domain/balance_config.dart';
import '../domain/battle_engine.dart';
import '../domain/game_state.dart';
import '../domain/offline_reward.dart';
import '../domain/save_codec.dart';
import '../domain/upgrade.dart';

/// 지금은 상수. 5주차에 서버 마스터 데이터로 교체된다.
final balanceConfigProvider = Provider<BalanceConfig>((_) => const BalanceConfig());

/// main()에서 실제 구현으로 override한다.
final saveRepositoryProvider = Provider<SaveRepository>(
  (_) => throw UnimplementedError('saveRepositoryProvider는 main에서 override한다'),
);

/// 저장 데이터를 반영한 시작 상태. main()에서 override한다.
final initialStateProvider = Provider<GameState>(
  (ref) => GameState.initial(ref.watch(balanceConfigProvider)),
);

/// 이번 실행에서 받은 오프라인 보상. 화면이 팝업 한 번 띄우는 데 쓴다.
final offlineRewardProvider = Provider<OfflineReward?>((_) => null);

final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

/// 마지막 저장 시각. 화면 하단 표시용.
final lastSavedAtProvider =
    NotifierProvider<LastSavedAt, DateTime?>(LastSavedAt.new);

class LastSavedAt extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void mark(DateTime at) => state = at;
}

/// 게임 루프. 100ms마다 [BattleEngine.tick]을 돌려 상태를 갱신하고,
/// 30초마다 + 앱이 백그라운드로 갈 때 저장한다 (GAME_DESIGN 12장 자동 저장).
class GameController extends Notifier<GameState> {
  static const _tick = Duration(milliseconds: 100);
  static const _autoSave = Duration(seconds: 30);

  late final BattleEngine _engine;
  final _rng = Random();
  Timer? _timer;
  Timer? _saveTimer;
  AppLifecycleListener? _lifecycle;

  @override
  GameState build() {
    final config = ref.watch(balanceConfigProvider);
    _engine = BattleEngine(config);
    _timer = Timer.periodic(_tick, (_) => _onTick());
    _saveTimer = Timer.periodic(_autoSave, (_) => saveNow());
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) {
        if (s != AppLifecycleState.resumed) saveNow();
      },
    );
    ref.onDispose(() {
      _timer?.cancel();
      _saveTimer?.cancel();
      _lifecycle?.dispose();
    });
    return ref.watch(initialStateProvider);
  }

  void _onTick() {
    state = _engine.tick(state, _tick.inMilliseconds / 1000, _rng);
  }

  void buyUpgrade(UpgradeType type) {
    final next = _engine.buyUpgrade(state, type);
    if (next != null) state = next;
  }

  Future<void> saveNow() async {
    final now = DateTime.now();
    await ref.read(saveRepositoryProvider).save(SaveData(state: state, savedAt: now));
    ref.read(lastSavedAtProvider.notifier).mark(now);
  }
}
