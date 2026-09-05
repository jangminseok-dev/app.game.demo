import 'package:flutter/material.dart';

import '../../domain/spirit.dart';
import 'pixel_ui.dart';

/// 정령이 나오는 순간의 컷신. **1.5초를 넘지 않고 건너뛸 수 없다**(스펙 7.3) —
/// 90초에 한 번이고, 이게 이 게임에서 제일 화려한 순간이다.
///
/// 소환 연출(`summon_flourish.dart`)과 파일이 다른 이유: 그쪽 공개 부분은 유물 전용이고
/// 공통은 private 하나뿐이다. 재사용이 아니라 두 번째 구현이다.
Future<void> showSpiritCutscene(BuildContext context, SpiritId id) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent, // 어둡게는 컷신이 직접 한다
    barrierDismissible: false, // 건너뛸 수 없다
    useSafeArea: false, // 노치 자리도 어두워져야 한다
    builder: (_) => _SpiritCutscene(id: id),
  );
}

/// 반투명 발광체. 6색 규격 밖이다 — 이펙트 취급이다(스펙 4.1).
class SpiritGlow extends StatelessWidget {
  const SpiritGlow({super.key, required this.progress, required this.color, required this.fade});

  /// 0~1. 커지는 정도.
  final double progress;

  final Color color;

  /// 0~1. 1이면 다 사라진 것이다.
  final double fade;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        height: 220,
        child: CustomPaint(painter: _GlowPainter(progress, color, fade)),
      );
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.progress, this.color, this.fade);

  final double progress;
  final Color color;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    // 사라질 때는 더 커지면서 옅어진다.
    final r = size.width / 2 * (0.3 + 0.7 * progress + 0.4 * fade);
    final alpha = (1 - fade).clamp(0.0, 1.0);

    // 바깥 무리와 안쪽 심지. 반투명이라 겹칠수록 밝아 보인다.
    canvas.drawCircle(center, r, Paint()..color = color.withValues(alpha: 0.22 * alpha));
    canvas.drawCircle(center, r * 0.62, Paint()..color = color.withValues(alpha: 0.38 * alpha));
    canvas.drawCircle(center, r * 0.3, Paint()..color = color.withValues(alpha: 0.7 * alpha));
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.progress != progress || old.color != color || old.fade != fade;
}

/// 구간 [from, to] 안에서 0~1로 흐르는 값.
double _phase(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

class _SpiritCutscene extends StatefulWidget {
  const _SpiritCutscene({required this.id});

  final SpiritId id;

  @override
  State<_SpiritCutscene> createState() => _SpiritCutsceneState();
}

class _SpiritCutsceneState extends State<_SpiritCutscene> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..forward().whenComplete(_close);

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.id.color);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final dim = _phase(t, 0, 0.15);
        final grow = Curves.easeOutCubic.transform(_phase(t, 0.15, 0.45));
        final fade = _phase(t, 0.70, 1.0);
        final nameOn = t >= 0.30 && t < 0.85;

        return SizedBox.expand(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.72 * dim * (1 - fade)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (grow > 0) SpiritGlow(progress: grow, color: color, fade: fade),
                if (nameOn)
                  Align(
                    alignment: const Alignment(0, 0.45),
                    child: PixelText(widget.id.label, size: 16, color: color),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
