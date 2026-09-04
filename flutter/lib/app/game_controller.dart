import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cloud_save_gateway.dart';
import '../data/save_repository.dart';
import '../domain/balance_config.dart';
import '../domain/battle_engine.dart';
import '../domain/codex.dart';
import '../domain/dungeon.dart';
import '../domain/game_state.dart';
import '../domain/hatchery.dart';
import '../domain/monster.dart';
import '../domain/offline_reward.dart';
import '../domain/save_codec.dart';
import '../domain/skill.dart';
import '../domain/upgrade.dart';

/// 서버 마스터 데이터(또는 캐시). main()에서 override한다. 없으면 내장 기본값.
final balanceConfigProvider = Provider<BalanceConfig>((_) => const BalanceConfig());

/// 몬스터 표. main()에서 override한다(서버 → 캐시 → 번들 에셋).
final monsterCatalogProvider = Provider<MonsterCatalog>((_) => MonsterCatalog.empty);

/// main()에서 실제 구현으로 override한다.
final saveRepositoryProvider = Provider<SaveRepository>(
  (_) => throw UnimplementedError('saveRepositoryProvider는 main에서 override한다'),
);

/// 서버 세이브. 로그인에 실패했으면 null — 로컬 저장만 한다.
final cloudSaveProvider = Provider<CloudSaveGateway?>((_) => null);

/// 저장 데이터를 반영한 시작 상태. main()에서 override한다.
final initialStateProvider = Provider<GameState>(
  (ref) => GameState.initial(ref.watch(balanceConfigProvider)),
);

/// 이번 실행에서 받은 오프라인 보상. 화면이 팝업 한 번 띄우는 데 쓴다.
final offlineRewardProvider = Provider<OfflineReward?>((_) => null);

final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

final saveStatusProvider = NotifierProvider<SaveStatusNotifier, SaveStatus>(SaveStatusNotifier.new);

/// 서버가 돌려준 포획 이벤트 큐. 화면이 알림으로 보여주고 [CaptureFeed.clear]한다.
final captureFeedProvider = NotifierProvider<CaptureFeed, List<CaptureEvent>>(CaptureFeed.new);

class CaptureFeed extends Notifier<List<CaptureEvent>> {
  @override
  List<CaptureEvent> build() => const [];
  void push(List<CaptureEvent> events) => state = [...state, ...events];
  void clear() => state = const [];
}

/// 화면 하단 표시용 저장·동기화 상태.
class SaveStatus {
  const SaveStatus({this.lastSavedAt, this.lastSyncedAt, this.lastRejectedRule});
  final DateTime? lastSavedAt;
  final DateTime? lastSyncedAt;
  final String? lastRejectedRule;

  SaveStatus copyWith({DateTime? lastSavedAt, DateTime? lastSyncedAt, String? lastRejectedRule}) =>
      SaveStatus(
        lastSavedAt: lastSavedAt ?? this.lastSavedAt,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastRejectedRule: lastRejectedRule ?? this.lastRejectedRule,
      );
}

class SaveStatusNotifier extends Notifier<SaveStatus> {
  @override
  SaveStatus build() => const SaveStatus();
  void saved(DateTime at) => state = state.copyWith(lastSavedAt: at);
  void synced(DateTime at) => state = SaveStatus(lastSavedAt: state.lastSavedAt, lastSyncedAt: at);
  void rejected(String rule) => state = state.copyWith(lastRejectedRule: rule);
}

/// 게임 루프. 100ms마다 [BattleEngine.tick]을 돌려 상태를 갱신하고,
/// 30초마다 + 앱이 백그라운드로 갈 때 저장·동기화한다 (GAME_DESIGN 12장).
class GameController extends Notifier<GameState> {
  static const _tick = Duration(milliseconds: 100);
  static const _autoSave = Duration(seconds: 30);

  late final BattleEngine _engine;
  final _rng = Random();
  Timer? _timer;
  Timer? _saveTimer;
  AppLifecycleListener? _lifecycle;
  bool _syncing = false;

  @override
  GameState build() {
    final config = ref.watch(balanceConfigProvider);
    _engine = BattleEngine(config, catalog: ref.watch(monsterCatalogProvider));
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

  /// 인벤토리를 전부 분해해 강화석으로 바꾼다. 착용 중인 장비는 건드리지 않는다.
  void scrapAll() {
    final next = state.equipment.scrapAll();
    if (!identical(next, state.equipment)) state = state.copyWith(equipment: next);
  }

  /// 입장권을 쓰고 던전 다음 층에 들어간다. 조건이 안 되면 아무 일도 안 일어난다.
  void enterDungeon(DungeonType type) {
    final next = _engine.enterDungeon(state, type, _rng);
    if (next != null) state = next;
  }

  /// 던전을 포기하고 필드로 돌아온다. 입장권은 돌려주지 않는다.
  void leaveDungeon() => state = _engine.leaveDungeon(state, cleared: false, rng: _rng);

  /// 스킬서 조각을 내고 스킬을 연다. 조각이 모자라면 아무 일도 안 일어난다.
  void unlockSkill(SkillId id) {
    final next = _engine.unlockSkill(state, id);
    if (next != null) state = next;
  }

  void equipSkill(int slot, SkillId id) => state = _engine.equipSkill(state, slot, id);

  void toggleSkillAuto(int slot) => state = _engine.toggleSkillAuto(state, slot);

  /// 탭으로 스킬을 즉시 쓴다. 대기 중이면 아무 일도 안 일어난다.
  void useSkill(int slot) {
    final next = _engine.useSkill(state, slot, _rng);
    if (next != null) state = next;
  }

  /// 알 조각을 내고 알을 올린다. 조각이 모자라면 아무 일도 안 일어난다.
  void startHatch(int index, EggKind kind) {
    final next = _engine.startHatch(state, index, kind);
    if (next != null) state = next;
  }

  /// 광고 보상으로 부화 시간을 줄인다.
  void speedUpHatch(int index) => state = _engine.speedUpHatch(state, index);

  /// 다 된 알을 꺼내 펫으로 만든다.
  void collectEgg(int index) {
    final next = _engine.collectEgg(state, index, _rng);
    if (next != null) state = next;
  }

  void sendExpedition(int index) {
    final next = _engine.sendExpedition(state, index);
    if (next != null) state = next;
  }

  void collectExpedition(int index) {
    final next = _engine.collectExpedition(state, index);
    if (next != null) state = next;
  }

  /// 데리고 다닐 펫을 바꾼다.
  void activatePet(int index) => state = state.copyWith(pets: state.pets.activate(index));

  /// 조건을 채운 퀘스트 보상을 받는다. 아직이면 아무 일도 안 일어난다.
  void claimQuest() {
    final next = _engine.claimQuest(state);
    if (next != null) state = next;
  }

  /// 강화석이 충분하면 강화를 한 단계 올린다. 실패도 파괴도 없다.
  void enhance() {
    final next = state.equipment.enhance();
    if (!identical(next, state.equipment)) state = state.copyWith(equipment: next);
  }

  /// 로컬 저장은 항상, 서버 동기화는 연결돼 있을 때.
  /// 수락: 보낸 처치 보고를 기록에서 빼고 포획 결과를 도감에 반영. 거부: 서버 상태로 롤백.
  Future<void> saveNow() async {
    final now = DateTime.now();
    await ref.read(saveRepositoryProvider).save(SaveData(state: state, savedAt: now));
    ref.read(saveStatusProvider.notifier).saved(now);

    final cloud = ref.read(cloudSaveProvider);
    if (cloud == null || _syncing) return;
    _syncing = true;
    final sent = state;
    try {
      final result = await cloud.sync(sent);
      if (result.accepted) {
        final consumed = _engine.consumeKillLog(state, sent.killLog, sent.bossKillLog);
        // 서버가 도감 전체를 돌려주면 그것이 정본(천장 진행 포함). 없으면 이벤트만 반영.
        state = result.codex != null
            ? _engine.withCodex(consumed, result.codex!, pity: result.pity ?? const {})
            : _engine.applyCaptures(consumed, result.captures);
        ref.read(saveStatusProvider.notifier).synced(DateTime.now());
        if (result.captures.isNotEmpty) ref.read(captureFeedProvider.notifier).push(result.captures);
      } else {
        state = _engine.withCodex(result.state, state.codex);
        ref.read(saveStatusProvider.notifier).rejected(result.rejectedRule ?? 'unknown');
      }
    } on Object {
      // 네트워크 오류 — 다음 주기에 다시 시도한다. 로컬 저장은 이미 됐고 처치 기록도 남아 있다.
    } finally {
      _syncing = false;
    }
  }
}
