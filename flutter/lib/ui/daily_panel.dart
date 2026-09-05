import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/daily.dart';
import '../domain/number_format.dart';
import 'hud/pixel_icons.dart';
import 'hud/pixel_ui.dart';
import 'hud/reward_popup.dart';

/// 오늘 과제 — 자정이 지나면 새로 시작한다.
///
/// 번호 퀘스트가 "어디까지 왔는가"라면 이쪽은 "오늘 무엇을 했는가"다.
class DailyPanel extends ConsumerWidget {
  const DailyPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const PixelText('자정이 지나면 새로 시작합니다', size: 10, color: PixelPalette.textDim),
        const SizedBox(height: 10),
        for (final goal in DailyGoal.values) ...[
          _DailyRow(
            goal: goal,
            progress: dailyProgress(goal, state),
            claimed: state.daily.isClaimed(goal),
            ready: dailyReady(goal, state),
            onClaim: () {
              final got = controller.claimDaily(goal);
              if (got == null) return;
              showRewardPopup(context, title: '오늘 과제', icon: PixelIcon.calendar, lines: [
                '${goal.reward.label} +${formatNumber(got.toDouble())}',
              ]);
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({
    required this.goal,
    required this.progress,
    required this.claimed,
    required this.ready,
    required this.onClaim,
  });

  final DailyGoal goal;
  final int progress;
  final bool claimed;
  final bool ready;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.all(10),
      color: claimed ? const Color(0xFF241E2B) : PixelPalette.panel,
      border: ready ? PixelPalette.gold : PixelPalette.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PixelText(
                  '${goal.label} ${goal.target}',
                  size: 12,
                  color: claimed ? PixelPalette.textDim : PixelPalette.text,
                ),
              ),
              GestureDetector(
                onTap: ready ? onClaim : null,
                child: PixelPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: ready ? PixelPalette.goldDark : const Color(0xFF3A3342),
                  child: PixelText(
                    claimed ? '받음' : (ready ? '받기' : '$progress/${goal.target}'),
                    size: 11,
                    color: ready ? PixelPalette.text : PixelPalette.textDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          PixelGauge(
            value: (progress / goal.target).clamp(0.0, 1.0),
            color: claimed ? PixelPalette.textDim : (ready ? PixelPalette.gold : PixelPalette.gem),
            height: 6,
          ),
          const SizedBox(height: 4),
          PixelText(
            '보상 ${goal.reward.label} +${formatNumber(goal.rewardAmount.toDouble())}',
            size: 10,
            color: PixelPalette.textDim,
          ),
        ],
      ),
    );
  }
}
