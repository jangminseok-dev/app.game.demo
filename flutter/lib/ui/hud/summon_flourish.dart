import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/summon.dart';
import 'pixel_ui.dart';

/// 소환 연출 한 벌 — 소환진 → 빛기둥 → 결과.
///
/// 심장은 결과가 아니라 **빛기둥**이다. 결과를 보기 전에 색으로 먼저 안다(스펙 7.1).
/// 금색 기둥이 올라오는 1초가 이 시스템에서 제일 좋은 1초다.
Future<void> showSummonFlourish(BuildContext context, List<SummonResult> results) {
  if (results.isEmpty) return Future<void>.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent, // 어둡게는 연출이 직접 한다 — 막이 먼저 깔리면 소환진이 안 보인다
    builder: (_) => _SummonFlourish(results: results),
  );
}

/// 굴린 성급이 기둥 색을 정한다. 승급 뒤 값이 아니다 —
/// 기둥은 "무엇이 나왔나"를 알리고 승급은 그 뒤에 일어난다.
Color pillarColorFor(int topStars) {
  if (topStars >= 5) return PixelPalette.gold;
  if (topStars == 4) return const Color(0xFFB388FF); // 보라. EquipGrade.epic과 같은 값이다
  if (topStars == 3) return PixelPalette.gem;
  return PixelPalette.text;
}

/// 바닥의 소환진. progress 0~1 동안 원이 시계방향으로 차오르고 룬이 켜진다.
class SummonCircle extends StatelessWidget {
  const SummonCircle({super.key, required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 160, height: 56, child: CustomPaint(painter: _CirclePainter(progress, color)));
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: size.width, height: size.height);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.9);

    // 원이 위쪽 12시부터 시계방향으로 차오른다.
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, line);

    // 룬 여덟. 원이 지나간 자리만 켠다.
    for (var i = 0; i < 8; i++) {
      final t = i / 8;
      if (t > progress) continue;
      final a = -math.pi / 2 + math.pi * 2 * t;
      final p = center + Offset(math.cos(a) * size.width / 2, math.sin(a) * size.height / 2);
      canvas.drawRect(Rect.fromCenter(center: p, width: 4, height: 4), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) => old.progress != progress || old.color != color;
}

/// 등급 색으로 자라는 빛기둥. **이 연출의 심장이다.**
class SummonPillar extends StatelessWidget {
  const SummonPillar({super.key, required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 60, height: 150, child: CustomPaint(painter: _PillarPainter(progress, color)));
}

class _PillarPainter extends CustomPainter {
  const _PillarPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final h = size.height * progress;
    final rect = Rect.fromLTWH(0, size.height - h, size.width, h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(rect),
    );
    // 가운데 심지는 진하게 — 픽셀 게임이라 경계가 또렷해야 한다.
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 3, size.height - h, 6, h),
      Paint()..color = color.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_PillarPainter old) => old.progress != progress || old.color != color;
}

/// 결과 한 줄. 테스트가 개수를 세므로 공개 위젯이다.
class SummonResultLine extends StatelessWidget {
  const SummonResultLine({super.key, required this.result});

  final SummonResult result;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: PixelText(
          summonResultLine(result),
          size: 12,
          color: result.upgraded ? PixelPalette.gold : PixelPalette.text,
        ),
      );
}

/// 구간 [from, to] 안에서 0~1로 흐르는 값. 밖이면 0이나 1이다.
double _phase(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

class _SummonFlourish extends StatefulWidget {
  const _SummonFlourish({required this.results});

  final List<SummonResult> results;

  @override
  State<_SummonFlourish> createState() => _SummonFlourishState();
}

class _SummonFlourishState extends State<_SummonFlourish> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 한 번 탭하면 건너뛰고, 끝난 뒤 탭하면 닫는다.
  void _tap() {
    if (_c.value < 1) {
      _c.value = 1;
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 기둥 색은 **굴린 값** 중 최고를 따른다(스펙 7.2 — 10연차도 기둥은 하나다).
    final top = widget.results.map((r) => r.stars).reduce(math.max);
    final color = pillarColorFor(top);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final dim = _phase(t, 0, 0.15);
          final circle = _phase(t, 0.15, 0.45);
          final pillar = _phase(t, 0.45, 0.80);
          final shown = t >= 0.80;

          // SizedBox.expand가 없으면 Stack이 자식 크기로 줄어 '아무 데나 탭'이 빗나간다.
          return SizedBox.expand(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.78 * dim),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (pillar > 0) SummonPillar(progress: pillar, color: color),
                  if (circle > 0)
                    Align(
                      alignment: const Alignment(0, 0.35),
                      child: SummonCircle(progress: circle, color: color),
                    ),
                  if (shown)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final r in widget.results) SummonResultLine(result: r),
                        const SizedBox(height: 20),
                        const PixelText('빈 곳을 터치하세요', size: 11, color: PixelPalette.textDim),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
