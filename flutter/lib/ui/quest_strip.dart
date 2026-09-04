import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/number_format.dart';
import '../domain/quest.dart';
import 'hud/pixel_ui.dart';

/// 화면에 늘 붙어 있는 퀘스트 한 줄.
///
/// 지금 할 일 하나와 다음 해금만 보여 준다. 목록을 늘어놓으면 고르는 일이 생기고,
/// 방치형에서 고민은 이탈로 이어진다.
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
        child: Row(
          children: [
            const PixelText('퀘스트를 모두 마쳤습니다', size: 12, color: PixelPalette.gold),
            const Spacer(),
            if (unlock != null)
              PixelText('다음 해금 ${unlock.$1}층 ${unlock.$2}', size: 10, color: PixelPalette.textDim),
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
        children: [
          Row(
            children: [
              PixelText('${quest.number}', size: 13, color: PixelPalette.gold),
              const SizedBox(width: 6),
              Expanded(child: PixelText(quest.label, size: 12)),
              PixelText(
                '${quest.reward.label} +${formatNumber(quest.rewardAmount.toDouble())}',
                size: 10,
                color: PixelPalette.textDim,
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: ready ? ref.read(gameControllerProvider.notifier).claimQuest : null,
                child: PixelPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: ready ? PixelPalette.goldDark : const Color(0xFF3A3342),
                  child: PixelText(
                    ready ? '받기' : '$progress/${quest.target}',
                    size: 11,
                    color: ready ? PixelPalette.text : PixelPalette.textDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          PixelGauge(
            value: quest.target == 0 ? 1 : (progress / quest.target).clamp(0.0, 1.0),
            color: ready ? PixelPalette.gold : PixelPalette.gem,
            height: 7,
          ),
          if (unlock != null) ...[
            const SizedBox(height: 4),
            PixelText('다음 해금 ${unlock.$1}층 ${unlock.$2}', size: 10, color: PixelPalette.textDim),
          ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: PixelPanel(
        padding: const EdgeInsets.all(8),
        border: ready ? PixelPalette.gold : PixelPalette.ink,
        child: child,
      ),
    );
  }
}
