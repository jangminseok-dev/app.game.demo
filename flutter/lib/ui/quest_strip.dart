import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/number_format.dart';
import '../domain/quest.dart';
import 'hud/pixel_icons.dart';
import 'hud/pixel_ui.dart';
import 'hud/reward_popup.dart';

/// 화면 왼쪽에 늘 붙어 있는 퀘스트 카드.
///
/// 지금 할 일 하나와 다음 해금만 보여 준다. 목록을 늘어놓으면 고르는 일이 생기고,
/// 방치형에서 고민은 이탈로 이어진다. 레퍼런스도 같은 자리에 같은 모양으로 둔다.
class QuestStrip extends ConsumerWidget {
  const QuestStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final quest = state.quests.current;
    final unlock = nextUnlock(state.highestStage);

    if (quest == null) {
      return _Frame(
        ready: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const PixelText('퀘스트를 모두 마쳤습니다', size: 11, color: PixelPalette.gold),
            if (unlock != null)
              PixelText('다음 해금 ${unlock.$1}층 ${unlock.$2}', size: 9, color: PixelPalette.textDim),
          ],
        ),
      );
    }

    final progress = questProgress(quest, state);
    final ready = progress >= quest.target;

    return _Frame(
      ready: ready,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PixelText('퀘스트 ${quest.number}', size: 11, color: PixelPalette.gold),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: ready
                    ? () {
                        ref.read(gameControllerProvider.notifier).claimQuest();
                        showRewardPopup(context, icon: PixelIcon.check, lines: [
                          '${quest.reward.label} +${formatNumber(quest.rewardAmount.toDouble())}',
                        ]);
                      }
                    : null,
                child: PixelPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  color: ready ? PixelPalette.goldDark : const Color(0xFF3A3342),
                  child: PixelText(
                    ready ? '받기' : '$progress/${quest.target}',
                    size: 10,
                    color: ready ? PixelPalette.text : PixelPalette.textDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          PixelText(quest.label, size: 11),
          const SizedBox(height: 4),
          SizedBox(
            width: 150,
            child: PixelGauge(
              value: quest.target == 0 ? 1 : (progress / quest.target).clamp(0.0, 1.0),
              color: ready ? PixelPalette.gold : PixelPalette.gem,
              height: 6,
            ),
          ),
          const SizedBox(height: 3),
          PixelText(
            '보상 ${quest.reward.label} +${formatNumber(quest.rewardAmount.toDouble())}',
            size: 9,
            color: PixelPalette.textDim,
          ),
          if (unlock != null)
            PixelText('다음 해금 ${unlock.$1}층 ${unlock.$2}', size: 9, color: PixelPalette.textDim),
        ],
      ),
    );
  }
}

/// 받을 수 있으면 테두리를 금색으로 바꾼다. 이것이 이 화면의 레드닷 역할을 한다.
class _Frame extends StatelessWidget {
  const _Frame({required this.ready, required this.child});

  final bool ready;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.all(7),
      border: ready ? PixelPalette.gold : PixelPalette.ink,
      child: child,
    );
  }
}
