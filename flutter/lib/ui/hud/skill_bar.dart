import 'package:flutter/material.dart';

import 'pixel_ui.dart';

/// 스킬 바 — 직업 스킬 3칸 + 펫 1칸. 자동 발동 + 탭 즉시 발동(기획).
///
/// 스킬 시스템(서브프로젝트 2)이 오기 전까지는 잠금 상태로 자리만 잡는다.
/// 레퍼런스처럼 잠긴 칸도 숨기지 않고 자물쇠로 보여 다음 목표를 알린다.
class SkillBar extends StatelessWidget {
  const SkillBar({super.key, this.unlocked = 0});

  /// 해금된 칸 수. 나머지는 자물쇠.
  final int unlocked;

  static const slots = 4;
  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < slots; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _SkillSlot(locked: i >= unlocked, pet: i == slots - 1),
            ),
        ],
      ),
    );
  }
}

class _SkillSlot extends StatelessWidget {
  const _SkillSlot({required this.locked, required this.pet});

  final bool locked;
  final bool pet;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: EdgeInsets.zero,
      color: locked ? const Color(0xFF241E2B) : PixelPalette.panelLight,
      border: pet ? PixelPalette.goldDark : PixelPalette.ink,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: locked
              ? const SizedBox(width: 16, height: 16, child: CustomPaint(painter: _LockIcon()))
              : Icon(pet ? Icons.pets : Icons.bolt, size: 20, color: PixelPalette.gold),
        ),
      ),
    );
  }
}

class _LockIcon extends CustomPainter {
  const _LockIcon();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFF6B5F78);
    final w = size.width, h = size.height;
    // 자물쇠 몸통 + 고리
    canvas.drawRect(Rect.fromLTWH(w * 0.18, h * 0.45, w * 0.64, h * 0.45), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.32, h * 0.18, w * 0.12, h * 0.3), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.56, h * 0.18, w * 0.12, h * 0.3), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.32, h * 0.18, w * 0.36, h * 0.12), p);
  }

  @override
  bool shouldRepaint(_LockIcon old) => false;
}
