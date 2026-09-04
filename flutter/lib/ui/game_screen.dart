import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/number_format.dart';
import '../domain/offline_reward.dart';
import '../domain/upgrade.dart';
import 'battle_area.dart';
import 'hud/skill_bar.dart';
import 'codex_screen.dart';
import 'dungeon_panel.dart';
import 'equipment_panel.dart';
import 'party_row.dart';

/// 메인 화면(세로): 전투 무대 → 편성 → 골드·업그레이드 → 저장 상태.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  int _tab = 0;

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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('받기'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final registered = state.codex.values.where((s) => s > 0).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('스테이지 ${state.stage}  (최고 ${state.highestStage})'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CodexScreen())),
            icon: const Icon(Icons.menu_book),
            label: Text('도감 $registered'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          // 세로 게임이라 데스크톱에서도 폰 폭으로 묶는다.
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            children: [
              const AspectRatio(aspectRatio: 4 / 3, child: BattleArea()),
          const SkillBar(),
              const Divider(height: 1),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: const [_UpgradeTab(), EquipmentPanel(), DungeonPanel(), _PartyTab(), CodexTab()],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 56,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.trending_up), label: '강화'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: state.equipment.canEnhance || state.equipment.inventory.isNotEmpty,
              child: const Icon(Icons.shield_outlined),
            ),
            label: '장비',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: state.dungeon.tickets > 0 && state.dungeon.run == null,
              label: Text('${state.dungeon.tickets}'),
              child: const Icon(Icons.castle_outlined),
            ),
            label: '던전',
          ),
          const NavigationDestination(icon: Icon(Icons.groups), label: '편성'),
          NavigationDestination(icon: const Icon(Icons.menu_book), label: '도감 $registered'),
        ],
      ),
    );
  }
}

/// 강화 탭 — 골드·능력치 5종·저장 상태.
class _UpgradeTab extends ConsumerWidget {
  const _UpgradeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final saveStatus = ref.watch(saveStatusProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final stats = state.statsWith(config);
    final mono = Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');
    final pending = state.killLog.values.fold(0, (a, b) => a + b) + state.bossKillLog.values.fold(0, (a, b) => a + b);
    return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('골드  ${formatNumber(state.gold)}', style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        Text('DPS ${formatNumber(stats.dps(config))}', style: mono),
                      ],
                    ),
                    Text(
                      '공격 ${formatNumber(stats.attack)}  속도 ${stats.attacksPerSecond.toStringAsFixed(1)}/s  '
                      '치명 ${(stats.critChance * 100).toStringAsFixed(0)}%  골드 ×${stats.goldMultiplier.toStringAsFixed(2)}',
                      style: mono?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                    const SizedBox(height: 8),
                    for (final type in UpgradeType.values)
                      _UpgradeRow(
                        type: type,
                        level: state.levelOf(type),
                        cost: type.cost(state.levelOf(type), config),
                        affordable: state.gold >= type.cost(state.levelOf(type), config),
                        onBuy: () => controller.buyUpgrade(type),
                      ),
                    const SizedBox(height: 16),
                    Text('총 처치 ${state.totalKills}  ·  미보고 처치 $pending', style: mono),
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
                );
  }
}

/// 편성 탭 — 동료 3칸 + 펫 1칸. 알·펫 서브프로젝트에서 채운다.
class _PartyTab extends StatelessWidget {
  const _PartyTab();

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(child: PartyRow());
}

String _saveLine(BuildContext context, SaveStatus s) {
  String hms(DateTime t) => '${TimeOfDay.fromDateTime(t).format(context)}:${t.second.toString().padLeft(2, '0')}';
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text('${type.label}  Lv.$level')),
          FilledButton(onPressed: affordable ? onBuy : null, child: Text('${formatNumber(cost)} G')),
        ],
      ),
    );
  }
}
