import 'package:flutter/material.dart';

import 'pixel_icons.dart';
import 'pixel_ui.dart';

/// 인게임 팝업 한 장. 전투 화면 위에 겹쳐 뜬다.
///
/// 레퍼런스처럼 기능마다 화면을 갈아 끼우지 않고 전투 위에 창을 띄운다.
/// 전투가 계속 돌아가는 것이 보여야 방치형의 "계속 크고 있다"는 감각이 끊기지 않는다.
class GamePopup extends StatelessWidget {
  const GamePopup({super.key, required this.title, required this.child, this.heightFactor = 0.72});

  final String title;
  final Widget child;

  /// 화면 높이 대비 팝업 높이.
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          width: 460,
          height: size.height * heightFactor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 제목 띠와 닫기 단추
              Row(
                children: [
                  PixelPanel(
                    color: PixelPalette.goldDark,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: PixelText(title, size: 14),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const PixelPanel(
                      color: Color(0xFF8C2F2F),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: PixelText('X', size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: PixelPanel(
                  padding: const EdgeInsets.all(4),
                  child: ClipRect(child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 전투 위에 팝업을 띄운다. 바깥을 누르면 닫힌다.
Future<void> showGamePopup(
  BuildContext context, {
  required String title,
  required Widget child,
  double heightFactor = 0.72,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => GamePopup(title: title, heightFactor: heightFactor, child: child),
  );
}

/// HUD의 둥근 기능 단추. 빨간 점으로 할 일이 있음을 알린다.
class HudButton extends StatelessWidget {
  const HudButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.alert = false,
    this.badge,
    this.locked = false,
    this.big = false,
  });

  final String label;
  final PixelIcon icon;
  final VoidCallback onTap;

  /// 빨간 점.
  final bool alert;

  /// 숫자 뱃지.
  final String? badge;

  /// 아직 없는 기능. 흐리게 그리고 자물쇠를 얹는다. 누르면 onTap이 '준비 중'을 띄운다.
  final bool locked;

  /// 하단 가운데 하나만 크게. 레퍼런스가 대장간을 그렇게 둔다.
  final bool big;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: locked ? 0.45 : 1,
                child: PixelPanel(
                  padding: EdgeInsets.all(big ? 11 : 7),
                  color: big ? PixelPalette.goldDark : PixelPalette.panelLight,
                  child: PixelIconView(icon, size: big ? 28 : 20),
                ),
              ),
              if (locked)
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: PixelPanel(
                    padding: const EdgeInsets.all(2),
                    color: PixelPalette.panelDark,
                    child: const PixelText('L', size: 8),
                  ),
                ),
              if (alert)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: Color(0xFFE5534B), shape: BoxShape.circle),
                  ),
                ),
              if (badge != null)
                Positioned(
                  right: -4,
                  top: -6,
                  child: PixelPanel(
                    color: const Color(0xFF8C2F2F),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: PixelText(badge!, size: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          PixelText(label, size: 9, color: PixelPalette.textDim),
        ],
      ),
    );
  }
}
