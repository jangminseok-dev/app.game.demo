import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/balance_config.dart';
import '../domain/dungeon.dart';
import '../domain/game_state.dart';
import '../domain/number_format.dart';
import 'hud/pixel_ui.dart';

/// 던전 화면 — 입장권 한 줄, 던전 4종 카드, 진행 중이면 진행 카드.
///
/// 던전마다 주는 재화가 다르고 그 재화를 쓰는 곳이 카드에 그대로 적혀 있다.
/// "오늘 무엇을 할까"가 이 화면 하나로 답이 나와야 한다.
class DungeonPanel extends ConsumerWidget {
  const DungeonPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final run = state.dungeon.run;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _TicketCard(dungeon: state.dungeon, config: config),
        const SizedBox(height: 12),
        if (run != null) ...[
          _RunCard(run: run, config: config, onLeave: controller.leaveDungeon),
          const SizedBox(height: 12),
        ],
        for (final type in DungeonType.values) ...[
          _DungeonCard(
            type: type,
            state: state,
            config: config,
            onEnter: () => controller.enterDungeon(type),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// 입장권 줄 — 남은 장수와 다음 한 장까지 남은 시간.
class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.dungeon, required this.config});

  final DungeonState dungeon;
  final BalanceConfig config;

  @override
  Widget build(BuildContext context) {
    final full = dungeon.tickets >= config.dungeonTicketCap;
    final leftSeconds = config.dungeonTicketSeconds - dungeon.ticketSeconds;
    return PixelPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const PixelText('입장권', size: 13),
          const SizedBox(width: 10),
          PixelText('${dungeon.tickets} / ${config.dungeonTicketCap}', size: 20, color: PixelPalette.gem),
          const Spacer(),
          PixelText(
            full ? '가득 찼습니다' : '다음 한 장 ${_hhmm(leftSeconds)}',
            size: 11,
            color: PixelPalette.textDim,
          ),
        ],
      ),
    );
  }
}

/// 진행 중인 판 — 남은 몬스터와 남은 시간, 포기 버튼.
class _RunCard extends StatelessWidget {
  const _RunCard({required this.run, required this.config, required this.onLeave});

  final DungeonRun run;
  final BalanceConfig config;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.all(12),
      border: PixelPalette.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelText('${run.type.label} ${run.floor}층 진행 중', size: 13, color: PixelPalette.gold),
              const Spacer(),
              _Button(label: '포기', enabled: true, onTap: onLeave),
            ],
          ),
          const SizedBox(height: 8),
          PixelGauge(value: run.timeLeft / config.dungeonTimeLimit, color: PixelPalette.boss),
          const SizedBox(height: 6),
          PixelText(
            '남은 몬스터 ${run.wavesLeft} · ${run.timeLeft.ceil()}초',
            size: 11,
            color: PixelPalette.textDim,
          ),
        ],
      ),
    );
  }
}

/// 던전 한 종류. 잠겨 있으면 여는 조건을 그대로 보여 준다.
class _DungeonCard extends StatelessWidget {
  const _DungeonCard({
    required this.type,
    required this.state,
    required this.config,
    required this.onEnter,
  });

  final DungeonType type;
  final GameState state;
  final BalanceConfig config;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final dungeon = state.dungeon;
    final unlocked = dungeon.isUnlocked(type, state.quests.claimed);
    final floor = dungeon.nextFloor(type);
    final required = dungeon.requiredStage(type, config);
    final floorReady = state.highestStage >= required;
    final reward = dungeonReward(type, floor, config);

    return PixelPanel(
      padding: const EdgeInsets.all(12),
      color: unlocked ? PixelPalette.panel : const Color(0xFF241E2B),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(
                  type.label,
                  size: 13,
                  color: unlocked ? PixelPalette.text : PixelPalette.textDim,
                ),
                const SizedBox(height: 3),
                // 어느 성장을 여는 던전인지 항상 보여 준다. 잠겨 있을 때도 마찬가지다.
                PixelText(
                  '${type.currency.label} → ${type.currency.sink}',
                  size: 10,
                  color: unlocked ? PixelPalette.gem : PixelPalette.textDim,
                ),
                const SizedBox(height: 4),
                if (!unlocked)
                  PixelText('퀘스트 ${type.unlockQuest}번을 마치면 열립니다',
                      size: 11, color: PixelPalette.textDim)
                else if (!floorReady)
                  PixelText('$floor층은 본편 $required층부터 들어갈 수 있습니다',
                      size: 11, color: PixelPalette.textDim)
                else ...[
                  PixelText(
                    '$floor층 도전 · ${type.currency.label} +${formatNumber(reward)}',
                    size: 11,
                    color: PixelPalette.gold,
                  ),
                  const SizedBox(height: 2),
                  PixelText('최고 ${dungeon.clearedFloor(type)}층', size: 10, color: PixelPalette.textDim),
                ],
              ],
            ),
          ),
          _Button(
            label: '입장',
            enabled: dungeon.canEnter(type, state.highestStage, state.quests.claimed, config),
            onTap: onEnter,
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: PixelPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        color: enabled ? PixelPalette.goldDark : const Color(0xFF3A3342),
        child: PixelText(label, size: 12, color: enabled ? PixelPalette.text : PixelPalette.textDim),
      ),
    );
  }
}

String _hhmm(double seconds) {
  final s = seconds.ceil().clamp(0, 1 << 30);
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  return h > 0 ? '$h시간 $m분' : '$m분';
}
