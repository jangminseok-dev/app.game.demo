import 'package:flutter/material.dart';

import 'pixel_icons.dart';
import 'pixel_ui.dart';

/// 팝업이 다루는 대상. 초상 열이 이 셋을 세운다(스펙 4.3).
///
/// 우하단 HUD 줄과 팝업 왼쪽 열이 같은 목록을 쓴다 — 둘이 갈라지면
/// "초상을 눌렀는데 다른 것이 열린다"가 된다.
enum PopupTarget {
  hero('주인공', '장비', PixelIcon.shield, '왼쪽은 입은 것, 오른쪽은 가방. 가방을 눌러 비교한다.'),
  pet('펫', '펫', PixelIcon.egg, '알을 부화하고 용을 탐험 보낸다. 둘 다 시간이 지나야 끝난다.'),
  ally('동료', '동료', PixelIcon.flag, null);

  const PopupTarget(this.portraitLabel, this.title, this.icon, this.help);

  /// 초상 아래 글자. 펫은 등급 이름이 있으면 그것으로 덮어쓴다.
  final String portraitLabel;

  /// 팝업 제목.
  final String title;

  final PixelIcon icon;
  final String? help;

  /// 아직 안 열린 대상. 자리는 있고 내용이 없다.
  bool get locked => this == PopupTarget.ally;
}

/// 초상 한 칸. 아직 그림이 없어 글자나 아이콘으로 채운다 — 초상화는 스펙 5.3.
class PortraitTile extends StatelessWidget {
  const PortraitTile({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.alert = false,
    this.locked = false,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  /// 빨간 점.
  final bool alert;

  /// 아직 없는 대상. 흐리게 그린다.
  final bool locked;

  /// 팝업 왼쪽 열에서 지금 보고 있는 대상. 테두리를 금색으로 바꾼다.
  final bool selected;

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
                  border: selected ? PixelPalette.gold : PixelPalette.ink,
                  child: SizedBox(width: 34, height: 34, child: Center(child: child)),
                ),
                if (alert)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      width: 9, height: 9,
                      decoration: const BoxDecoration(color: Color(0xFFE5534B), shape: BoxShape.circle),
                    ),
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

/// 대상의 얼굴. 그림이 들어오기 전까지 글자와 아이콘으로 버틴다.
Widget portraitFace(PopupTarget target) => switch (target) {
      PopupTarget.hero => const PixelText('나', size: 12, color: PixelPalette.gold),
      PopupTarget.pet => PixelIconView(PixelIcon.egg, size: 16),
      PopupTarget.ally => const PixelText('L', size: 10),
    };
