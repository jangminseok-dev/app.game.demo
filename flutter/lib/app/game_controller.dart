import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/balance_config.dart';
import '../domain/battle_engine.dart';
import '../domain/game_state.dart';
import '../domain/upgrade.dart';

/// 지금은 상수. 5주차에 서버 마스터 데이터로 교체된다.
final balanceConfigProvider = Provider<BalanceConfig>((_) => const BalanceConfig());

final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

/// 게임 루프. 100ms마다 [BattleEngine.tick]을 돌려 상태를 갱신한다.
class GameController extends Notifier<GameState> {
  static const _tick = Duration(milliseconds: 100);

  late final BattleEngine _engine;
  final _rng = Random();
  Timer? _timer;

  @override
  GameState build() {
    final config = ref.watch(balanceConfigProvider);
    _engine = BattleEngine(config);
    _timer = Timer.periodic(_tick, (_) => _onTick());
    ref.onDispose(() => _timer?.cancel());
    return GameState.initial(config);
  }

  void _onTick() {
    state = _engine.tick(state, _tick.inMilliseconds / 1000, _rng);
  }

  void buyUpgrade(UpgradeType type) {
    final next = _engine.buyUpgrade(state, type);
    if (next != null) state = next;
  }
}
