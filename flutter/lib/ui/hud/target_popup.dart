import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../equipment_panel.dart';
import '../pet_panel.dart';
import 'game_popup.dart';
import 'pixel_ui.dart';
import 'portrait_tile.dart';

/// 대상이 있는 팝업 — 왼쪽 초상 열에서 주인공·펫·동료를 갈아 끼운다(스펙 4.3).
///
/// 초상은 팝업 **밖** 왼쪽에 남는다. 눌러도 창이 새로 뜨지 않고 안쪽 내용만 바뀐다.
/// 창이 쌓이면 뒤로 가기가 몇 번인지 알 수 없게 된다.
Future<void> showTargetPopup(BuildContext context, PopupTarget target) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _TargetPopup(initial: target),
  );
}

class _TargetPopup extends StatefulWidget {
  const _TargetPopup({required this.initial});

  final PopupTarget initial;

  @override
  State<_TargetPopup> createState() => _TargetPopupState();
}

class _TargetPopupState extends State<_TargetPopup> {
  late PopupTarget _target = widget.initial;

  @override
  Widget build(BuildContext context) {
    return GamePopup(
      title: _target.title,
      icon: _target.icon,
      help: _target.help,
      leading: _PortraitColumn(
        selected: _target,
        onSelect: (t) => setState(() => _target = t),
      ),
      child: switch (_target) {
        PopupTarget.hero => const EquipmentPanel(),
        PopupTarget.pet => const PetPanel(),
        PopupTarget.ally => const Center(
            child: PixelText('동료 — 준비 중', size: 12, color: PixelPalette.textDim),
          ),
      },
    );
  }
}

/// 팝업 왼쪽에 세로로 서는 초상 열. AUTO는 전투 조작이라 여기 없다.
class _PortraitColumn extends ConsumerWidget {
  const _PortraitColumn({required this.selected, required this.onSelect});

  final PopupTarget selected;
  final ValueChanged<PopupTarget> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in PopupTarget.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PortraitTile(
              // 테스트가 HUD 줄의 같은 초상과 구별할 수 있게 팝업 열에만 이름을 준다.
              key: ValueKey('popup-portrait-${t.name}'),
              label: t == PopupTarget.pet
                  ? (state.pets.active?.grade.label ?? t.portraitLabel)
                  : t.portraitLabel,
              alert: t == PopupTarget.pet && state.hatchery.hasReady,
              locked: t.locked,
              selected: t == selected,
              onTap: () => onSelect(t),
              child: portraitFace(t),
            ),
          ),
      ],
    );
  }
}
