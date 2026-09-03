import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/codex.dart';
import '../domain/number_format.dart';
import '../domain/offline_reward.dart';
import '../domain/upgrade.dart';
import 'codex_screen.dart';

/// 텍스트 전투 화면. 그래픽 없이 숫자와 이름만 보여준다.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    final reward = ref.read(offlineRewardProvider);
    if (reward != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOfflineReward(reward));
    }
  }

  void _showOfflineReward(OfflineReward reward) {
    final h = reward.elapsed.inHours;
    final m = reward.elapsed.inMinutes % 60;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오프라인 보상'),
        content: Text('${h > 0 ? '$h시간 ' : ''}$m분 동안 자동 사냥\n골드 +${formatNumber(reward.gold)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('받기')),
        ],
      ),
    );
  }

  void _showCaptures(List<CaptureEvent> captures) {
    final catalog = ref.read(monsterCatalogProvider);
    final lines = captures.map((c) {
      final name = catalog.byId(c.monsterId)?.name ?? '몬스터 #${c.monsterId}';
      return c.first ? '$name 도감 등록!' : '$name ★${c.stars}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('포획: ${lines.join(', ')}'), duration: const Duration(seconds: 4)),
    );
    ref.read(captureFeedProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(captureFeedProvider, (_, events) {
      if (events.isNotEmpty) _showCaptures(events);
    });

    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final catalog = ref.watch(monsterCatalogProvider);
    final saveStatus = ref.watch(saveStatusProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final stats = state.stats;
    final mono = Theme.of(context).textTheme.bodyLarge?.copyWith(fontFamily: 'monospace');
    final monster = catalog.byId(state.monsterId);
    final monsterLabel = monster == null ? '몬스터' : '${monster.name} [${monster.element.label}]';
    final registered = state.codex.values.where((s) => s > 0).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('스테이지 ${state.stage}  (최고 ${state.highestStage})'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CodexScreen()),
            ),
            icon: const Icon(Icons.menu_book),
            label: Text('도감 $registered'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            state.isBoss
                ? '보스 $monsterLabel  ${state.bossTimeLeft.toStringAsFixed(1)}초 남음'
                : '$monsterLabel  ${state.killsOnStage}/${config.killsPerStage}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (monster != null)
            Text(
              state.starsOf(monster.id) > 0
                  ? '도감 ★${state.starsOf(monster.id)}  ${monster.passiveKind.label} ★당 ${monster.passiveKind.format(monster.passivePerStar)}'
                  : '미등록  포획 확률 ${(stats.captureRate * monster.rarity * (state.isBoss ? config.bossCaptureMultiplier : 1) * 100).toStringAsFixed(2)}%',
              style: mono?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: state.monsterMaxHp == 0 ? 0 : state.monsterHp / state.monsterMaxHp,
            color: state.isBoss ? Colors.red : null,
          ),
          Text('HP ${formatNumber(state.monsterHp)} / ${formatNumber(state.monsterMaxHp)}', style: mono),
          const Divider(height: 32),
          Text('골드  ${formatNumber(state.gold)}', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'DPS ${formatNumber(stats.dps(config))}  '
            '공격 ${formatNumber(stats.attack)}  '
            '속도 ${stats.attacksPerSecond.toStringAsFixed(1)}/s  '
            '치명 ${(stats.critChance * 100).toStringAsFixed(0)}%  '
            '골드 ×${stats.goldMultiplier.toStringAsFixed(2)}',
            style: mono,
          ),
          const Divider(height: 32),
          for (final type in UpgradeType.values)
            _UpgradeRow(
              type: type,
              level: state.levelOf(type),
              cost: type.cost(state.levelOf(type), config),
              affordable: state.gold >= type.cost(state.levelOf(type), config),
              onBuy: () => controller.buyUpgrade(type),
            ),
          const SizedBox(height: 24),
          Text('총 처치 ${state.totalKills}  ·  미보고 처치 ${state.killLog.values.fold(0, (a, b) => a + b) + state.bossKillLog.values.fold(0, (a, b) => a + b)}', style: mono),
          Text(
            _saveLine(context, saveStatus),
            style: mono?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          if (saveStatus.lastRejectedRule != null)
            Text(
              '서버 검증 거부(${saveStatus.lastRejectedRule}) — 서버 상태로 되돌렸습니다',
              style: mono?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

String _saveLine(BuildContext context, SaveStatus s) {
  String hms(DateTime t) =>
      '${TimeOfDay.fromDateTime(t).format(context)}:${t.second.toString().padLeft(2, '0')}';
  final saved = s.lastSavedAt == null ? '저장 전' : '로컬 저장 ${hms(s.lastSavedAt!)}';
  final synced = s.lastSyncedAt == null ? '서버 미동기화' : '서버 동기화 ${hms(s.lastSyncedAt!)}';
  return '$saved · $synced';
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.type,
    required this.level,
    required this.cost,
    required this.affordable,
    required this.onBuy,
  });

  final UpgradeType type;
  final int level;
  final double cost;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text('${type.label}  Lv.$level')),
          FilledButton(
            onPressed: affordable ? onBuy : null,
            child: Text('${formatNumber(cost)} G'),
          ),
        ],
      ),
    );
  }
}
