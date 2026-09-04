import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/equipment.dart';
import '../domain/number_format.dart';
import 'hud/pixel_ui.dart';
import 'hud/reward_popup.dart';

/// 대장간 — 강화석을 두드려 장비를 만든다.
///
/// 강화석의 소비처가 둘이 된다. 지금 강화할까 새로 만들까가 매번 선택이 된다.
/// 두드릴수록 숙련도가 올라 좋은 등급이 잘 나온다.
class ForgePanel extends ConsumerWidget {
  const ForgePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final eq = state.equipment;
    final controller = ref.read(gameControllerProvider.notifier);
    final cost = eq.craftCost(config);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PixelPanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PixelText('숙련도 ${eq.craftLevel}', size: 16, color: PixelPalette.gold),
                  const Spacer(),
                  PixelText('강화석 ${eq.stones}', size: 11, color: PixelPalette.textDim),
                ],
              ),
              const SizedBox(height: 8),
              PixelGauge(
                value: (eq.stones / cost).clamp(0.0, 1.0),
                color: eq.canCraft(config) ? PixelPalette.gold : PixelPalette.gem,
                height: 8,
              ),
              const SizedBox(height: 6),
              PixelText('한 번 두드리는 데 강화석 $cost', size: 11, color: PixelPalette.textDim),
              const SizedBox(height: 2),
              PixelText('두드릴수록 좋은 등급이 잘 나옵니다', size: 10, color: PixelPalette.textDim),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PixelPanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PixelText('지금 만들면', size: 12),
              const SizedBox(height: 6),
              PixelText('티어 ${(state.stage - 1) ~/ config.equipStagesPerTier}',
                  size: 11, color: PixelPalette.textDim),
              const SizedBox(height: 2),
              PixelText('부위는 무작위이고 더 세면 자동으로 입습니다',
                  size: 10, color: PixelPalette.textDim),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: eq.canCraft(config)
                ? () {
                    final made = controller.craft();
                    if (made == null) return;
                    showRewardPopup(context, title: '제작', lines: [_line(made)]);
                  }
                : null,
            child: PixelPanel(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              color: eq.canCraft(config) ? PixelPalette.goldDark : const Color(0xFF3A3342),
              child: PixelText(
                '제작',
                size: 15,
                color: eq.canCraft(config) ? PixelPalette.text : PixelPalette.textDim,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _line(Equipment made) =>
      '${made.label} · 공격력 +${formatNumber(made.power)}';
}
