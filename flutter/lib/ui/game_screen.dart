import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/number_format.dart';
import '../domain/upgrade.dart';

/// 1주차 텍스트 화면. 그래픽 없이 숫자만 보여준다.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final stats = state.stats;
    final mono = Theme.of(context).textTheme.bodyLarge?.copyWith(fontFamily: 'monospace');

    return Scaffold(
      appBar: AppBar(title: Text('스테이지 ${state.stage}  (최고 ${state.highestStage})')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            state.isBoss
                ? '보스  ${state.bossTimeLeft.toStringAsFixed(1)}초 남음'
                : '몬스터  ${state.killsOnStage}/${config.killsPerStage}',
            style: Theme.of(context).textTheme.titleLarge,
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
          Text('총 처치 ${state.totalKills}', style: mono),
        ],
      ),
    );
  }
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
