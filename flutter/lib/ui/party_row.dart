import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/skill.dart';
import 'hud/game_popup.dart';
import 'hud/pixel_icons.dart';
import 'hud/pixel_ui.dart';
import 'pet_panel.dart';

/// 우하단 초상 줄 — AUTO · 주인공 · 펫 · 동료.
///
/// 같이 싸우는 것들이 한 줄에 선다. 초상을 누르면 그 대상의 창이 열린다.
/// 다음 계획(팝업 골격)에서 이 줄이 팝업 왼쪽에도 붙는다 — 그래서 위젯으로 뺐다.
class PartyPortraits extends ConsumerWidget {
  const PartyPortraits({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final allAuto = List.generate(SkillState.slots, state.skills.isAuto).every((a) => a);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AUTO — 셋 다 켜져 있으면 끄고, 하나라도 꺼져 있으면 다 켠다.
        GestureDetector(
          onTap: () {
            for (var i = 0; i < SkillState.slots; i++) {
              if (state.skills.isAuto(i) == allAuto) controller.toggleSkillAuto(i);
            }
          },
          child: PixelPanel(
            padding: const EdgeInsets.all(6),
            color: allAuto ? PixelPalette.goldDark : PixelPalette.panelDark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PixelIconView(PixelIcon.auto, size: 14),
                const PixelText('AUTO', size: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _Portrait(label: '주인공', onTap: null, child: const PixelText('나', size: 12, color: PixelPalette.gold)),
        const SizedBox(width: 4),
        _Portrait(
          label: state.pets.active?.grade.label ?? '펫',
          alert: state.hatchery.hasReady,
          onTap: () => showGamePopup(context, title: '펫', icon: PixelIcon.egg,
              help: '알을 부화하고 용을 탐험 보낸다. 둘 다 시간이 지나야 끝난다.', child: const PetPanel()),
          child: PixelIconView(PixelIcon.egg, size: 16),
        ),
        const SizedBox(width: 4),
        _Portrait(
          label: '동료',
          locked: true,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: PixelText('동료 — 준비 중', size: 12), duration: const Duration(seconds: 1)),
          ),
          child: const PixelText('L', size: 10),
        ),
      ],
    );
  }
}

/// 초상 한 칸. 아직 그림이 없어 글자나 아이콘으로 채운다 — 초상화는 스펙 5.3.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.label, required this.child, required this.onTap, this.alert = false, this.locked = false});

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool alert;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PixelPanel(
                  padding: EdgeInsets.zero,
                  color: PixelPalette.panelLight,
                  child: SizedBox(width: 34, height: 34, child: Center(child: child)),
                ),
                if (alert)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFE5534B), shape: BoxShape.circle)),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            PixelText(label, size: 8, color: PixelPalette.textDim),
          ],
        ),
      ),
    );
  }
}
