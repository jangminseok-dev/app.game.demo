import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/summon.dart';
import 'pixel_icons.dart';
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
    useSafeArea: false, // 어둡게를 연출 자식이 그리므로 노치·홈바 자리까지 덮어야 한다
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

/// 등급이 셀수록 요란하다. 색만 바꾸면 ★1과 ★5가 같은 무게로 느껴진다.
({int sparks, double flash}) flourishForce(int topStars) => switch (topStars) {
      >= 5 => (sparks: 18, flash: 1.0),
      4 => (sparks: 12, flash: 0.7),
      3 => (sparks: 8, flash: 0.45),
      _ => (sparks: 4, flash: 0.25),
    };

/// 결과가 보이기 시작하는 지점. 여기부터는 탭이 '건너뛰기'가 아니라 '닫기'다 —
/// 화면이 "빈 곳을 터치하세요"라고 말하는 동안 탭이 먹통이면 안 된다.
/// `flashAt` 도 이 값을 참조한다 — 섬광이 카드 위로 번지면 안 된다.
const resultAt = 0.80;

/// 기둥이 다 자란 순간의 흰 섬광. **결과 카드가 뜨기 전에 꺼져야 한다** —
/// 카드 위로 번지면 제일 중요한 순간(특히 ★5)에 글자가 안 읽힌다.
double flashAt(double t) {
  const start = 0.72;
  const end = resultAt; // 0.80
  if (t < start || t >= end) return 0;
  final x = (t - start) / (end - start); // 0~1
  return (1 - (x * 2 - 1).abs()) * 0.55; // 가운데(t=0.76)서 0.55, 양끝 0
}

/// 소환진 높이. 기둥 바닥을 여기 중앙에 붙이는 계산에도 쓴다.
const _circleHeight = 56.0;

/// 바닥의 소환진. progress 0~1 동안 원이 시계방향으로 차오르고 룬이 켜진다.
class SummonCircle extends StatelessWidget {
  const SummonCircle({super.key, required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 160, height: _circleHeight, child: CustomPaint(painter: _CirclePainter(progress, color)));
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

/// 소환진에서 위로 튀는 사각 파티클. 개수는 등급을 따른다.
class SummonSparks extends StatelessWidget {
  const SummonSparks({super.key, required this.progress, required this.color, required this.count});

  final double progress;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 200, height: 170, child: CustomPaint(painter: _SparkPainter(progress, color, count)));
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.progress, this.color, this.count);

  final double progress;
  final Color color;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final origin = Offset(size.width / 2, size.height);
    final fill = Paint();
    for (var i = 0; i < count; i++) {
      // 각도·속도를 인덱스로 정한다 — 프레임마다 Random()을 새로 뽑으면 자리가 지지직거린다.
      final angle = i * 2.399; // 황금각(라디안). 파티클을 고르게 흩는다.
      final speed = 0.55 + (i % 4) * 0.12; // 파티클마다 조금씩 다른 속도
      final dx = math.cos(angle) * size.width * 0.42 * progress;
      final dy = -size.height * 0.85 * progress * speed;
      fill.color = color.withValues(alpha: (1 - progress).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromCenter(center: origin + Offset(dx, dy), width: 3, height: 3), fill);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress || old.color != color || old.count != count;
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
          color: result.upgraded && result.after > result.before ? PixelPalette.gold : PixelPalette.text,
        ),
      );
}

/// 결과 카드. 4.8(`reward_popup.dart`)과 같은 문법이다 —
/// `결과` 라벨 → 아이콘 패널(금테) → 결과 줄(금테 패널) → '빈 곳을 터치하세요'.
/// 카드가 바탕을 가지므로 뒤에서 아직 켜져 있는 기둥·소환진과도 안 겹친다.
class _SummonResultCard extends StatelessWidget {
  const _SummonResultCard({required this.results});

  final List<SummonResult> results;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PixelText('결과', size: 12, color: PixelPalette.textDim),
          const SizedBox(height: 10),
          const PixelPanel(
            padding: EdgeInsets.all(10),
            border: PixelPalette.gold,
            child: PixelIconView(PixelIcon.spark, size: 36),
          ),
          const SizedBox(height: 12),
          PixelPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            border: PixelPalette.gold,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final r in results) SummonResultLine(result: r)],
            ),
          ),
          const SizedBox(height: 20),
          const PixelText('빈 곳을 터치하세요', size: 11, color: PixelPalette.textDim),
        ],
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

  /// 결과가 보이기 전 탭하면 건너뛰고, 보인 뒤 탭하면 닫는다.
  void _tap() {
    if (_c.value < resultAt) {
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
    final force = flourishForce(top);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final dim = _phase(t, 0, 0.15);
          final circle = _phase(t, 0.15, 0.45);
          // 기둥 구간은 선형 그대로 두지 않는다 — easeOutCubic으로 솟았다가 감속해야 "쿵" 하는 순간이 산다.
          // 소환진은 계속 선형이다(원이 일정한 속도로 그어져야 룬이 규칙적으로 켜진다).
          final rawPillar = _phase(t, 0.45, resultAt);
          final pillar = Curves.easeOutCubic.transform(rawPillar);
          final shown = t >= resultAt;

          // SizedBox.expand가 없으면 Stack이 자식 크기로 줄어 '아무 데나 탭'이 빗나간다.
          return SizedBox.expand(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.78 * dim),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (rawPillar > 0 || circle > 0)
                    // 기둥·소환진·파티클을 같은 Align에 얹는다 — 기준이 갈리면 화면이 커질수록 벌어진다.
                    // 기둥 바닥이 소환진 중심에 오도록 기둥에 소환진 높이의 절반만큼 아래 여백을 준다.
                    Align(
                      alignment: const Alignment(0, 0.35),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          if (rawPillar > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: _circleHeight / 2),
                              child: SummonPillar(progress: pillar, color: color),
                            ),
                          if (circle > 0) SummonCircle(progress: circle, color: color),
                          if (rawPillar > 0)
                            SummonSparks(progress: rawPillar, color: color, count: force.sparks),
                        ],
                      ),
                    ),
                  if (shown) _SummonResultCard(results: widget.results),
                  // 기둥이 다 자라는 순간의 흰 섬광. 세기는 등급을 따른다 — 색만 바꾸면 ★1과 ★5가 같은 무게로 느껴진다.
                  IgnorePointer(
                    child: SizedBox.expand(
                      child: ColoredBox(color: Colors.white.withValues(alpha: flashAt(t) * force.flash)),
                    ),
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
