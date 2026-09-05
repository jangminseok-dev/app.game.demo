import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/skill.dart';
import 'hud/pixel_icons.dart';
import 'hud/pixel_ui.dart';
import 'hud/portrait_tile.dart';

/// 우하단 초상 줄 — AUTO · 주인공 · 펫 · 동료.
///
/// 같이 싸우는 것들이 한 줄에 선다. 무엇을 열지는 이 위젯이 정하지 않는다 —
/// 팝업 왼쪽 열도 같은 초상을 쓰는데, 거기서는 창을 새로 띄우면 안 되기 때문이다.
class PartyPortraits extends ConsumerWidget {
  const PartyPortraits({super.key, required this.onSelect});

  /// 초상을 눌렀을 때. HUD에서는 팝업을 열고, 팝업 안에서는 내용을 바꾼다.
  final ValueChanged<PopupTarget> onSelect;

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
        for (final t in PopupTarget.values) ...[
          PortraitTile(
            label: t == PopupTarget.pet
                ? (state.pets.active?.grade.label ?? t.portraitLabel)
                : t.portraitLabel,
            alert: t == PopupTarget.pet && state.hatchery.hasReady,
            locked: t.locked,
            onTap: () => onSelect(t),
            child: portraitFace(t),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }
}
