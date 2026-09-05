import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hud_metrics.dart';
import 'pixel_icons.dart';
import 'pixel_ui.dart';

/// 인게임 팝업 한 장. 전투 화면 위에 겹쳐 뜬다.
///
/// 레퍼런스처럼 기능마다 화면을 갈아 끼우지 않고 전투 위에 창을 띄운다.
/// 전투가 계속 돌아가는 것이 보여야 방치형의 "계속 크고 있다"는 감각이 끊기지 않는다.
///
/// 골격은 스펙 4절이다. 새 팝업은 예외 없이 이 위젯을 쓴다 —
/// 제목 리본은 좌상단, 닫기는 우상단 빨간 원, 하단 HUD는 안 덮는다.
class GamePopup extends StatelessWidget {
  const GamePopup({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.help,
    this.heightFactor = 0.72,
    this.leading,
  });

  final String title;

  /// 제목 리본 왼쪽 그림.
  final PixelIcon icon;

  final Widget child;

  /// `?` 를 눌렀을 때 나오는 설명. 없으면 `?` 를 안 그린다.
  final String? help;

  /// 화면 높이 대비 팝업 높이. 하단 HUD 자리를 뺀 나머지를 넘지 못한다.
  final double heightFactor;

  /// 팝업 **밖** 왼쪽에 붙는 것. 초상 열이 여기 들어간다(스펙 4.3).
  final Widget? leading;

  /// 초상 칸 폭 + 사이 간격. leading이 있을 때 본체 폭에서 뺀다.
  static const _leadingWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // 아래를 hudBottomInset 만큼 비운다 — 하단 바와 우하단 스킬칸이 계속 보인다(스펙 4.6).
        padding: const EdgeInsets.fromLTRB(10, 6, 10, hudBottomInset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(
              460.0,
              constraints.maxWidth - (leading == null ? 0.0 : _leadingWidth),
            );
            final height = math.min(
              MediaQuery.sizeOf(context).height * heightFactor,
              constraints.maxHeight,
            );
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 6),
                  ],
                  SizedBox(width: width, height: height, child: _body(context)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 제목 리본과 닫기 (스펙 4.1·4.2)
        Row(
          children: [
            PixelPanel(
              color: PixelPalette.goldDark,
              padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelIconView(icon, size: 16),
                  const SizedBox(width: 6),
                  PixelText(title, size: 14),
                ],
              ),
            ),
            if (help != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showHelp(context),
                child: const _RoundChip(color: PixelPalette.panelLight, label: '?'),
              ),
            ],
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const _RoundChip(color: Color(0xFF8C2F2F), label: 'X'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: PixelPanel(
            key: const Key('popup-body'),
            padding: const EdgeInsets.all(4),
            child: ClipRect(child: child),
          ),
        ),
      ],
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => Center(
        child: PixelPanel(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText('$title 도움말', size: 12, color: PixelPalette.gold),
                const SizedBox(height: 8),
                PixelText(help!, size: 11, color: PixelPalette.textDim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 둥근 칩 — 닫기 ✕ 와 도움말 ? (스펙 4.1·4.2). 사각 패널과 달리 원이라 눈에 먼저 띈다.
class _RoundChip extends StatelessWidget {
  const _RoundChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: PixelPalette.ink, width: 2),
      ),
      child: Center(child: PixelText(label, size: 13)),
    );
  }
}

/// 전투 위에 팝업을 띄운다. 바깥을 누르면 닫힌다.
Future<void> showGamePopup(
  BuildContext context, {
  required String title,
  required PixelIcon icon,
  required Widget child,
  String? help,
  double heightFactor = 0.72,
  Widget? leading,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => GamePopup(
      title: title,
      icon: icon,
      help: help,
      heightFactor: heightFactor,
      leading: leading,
      child: child,
    ),
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
