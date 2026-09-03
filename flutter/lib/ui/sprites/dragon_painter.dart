import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/monster.dart';
import 'monster_sprite.dart';

/// 아기 용 — 코드 벡터 아트의 상한을 보여주는 스파이크.
///
/// 96×96 기준, 왼쪽(주인공 쪽)을 본다. 둥근 몸통·연한 배·작은 날개·뿔·큰 눈·볼터치·꼬리.
/// 팔레트는 속성색에서 파생한다(몸통 / 배 / 진한 외곽선 / 날개막).
class DragonPainter extends CustomPainter {
  const DragonPainter({required this.monster, this.isBoss = false, this.silhouette = false, this.blink = 0});

  final Monster? monster;
  final bool isBoss;
  final bool silhouette;

  /// 0~1. 1에 가까울수록 눈을 감는다(깜빡임 연출).
  final double blink;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 96; // 1u = 96 기준 1px
    final base = monster == null ? const Color(0xFFE85D3A) : elementColor(monster!.element);
    final variant = monster == null ? 0 : (monster!.id - 1) % 10;
    final h = HSLColor.fromColor(base);
    final body = silhouette ? const Color(0xFF111827) : h.withHue((h.hue + variant * 7) % 360).withSaturation(0.65).withLightness(0.55).toColor();
    final belly = silhouette ? body : h.withSaturation(0.35).withLightness(0.85).toColor();
    final dark = silhouette ? const Color(0xFF0B1220) : h.withSaturation(0.7).withLightness(0.28).toColor();
    final wing = silhouette ? body : h.withSaturation(0.55).withLightness(0.42).toColor();
    final outline = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * u
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..style = PaintingStyle.fill;

    // 그림자
    canvas.drawOval(
      Rect.fromCenter(center: Offset(50 * u, 88 * u), width: 54 * u, height: 10 * u),
      Paint()..color = Colors.black.withValues(alpha: silhouette ? 0.0 : 0.18),
    );

    // 꼬리 (오른쪽으로 말림)
    final tail = Path()
      ..moveTo(66 * u, 62 * u)
      ..cubicTo(84 * u, 60 * u, 92 * u, 46 * u, 82 * u, 40 * u)
      ..cubicTo(78 * u, 38 * u, 76 * u, 44 * u, 80 * u, 46 * u)
      ..cubicTo(86 * u, 50 * u, 78 * u, 58 * u, 66 * u, 56 * u)
      ..close();
    canvas.drawPath(tail, fill..color = body);
    canvas.drawPath(tail, outline);
    // 꼬리 끝 하트형 촉
    final tip = Path()
      ..moveTo(82 * u, 40 * u)
      ..lineTo(90 * u, 34 * u)
      ..lineTo(84 * u, 46 * u)
      ..close();
    canvas.drawPath(tip, fill..color = dark);

    // 뒷날개
    _wing(canvas, u, Offset(58 * u, 44 * u), 1.0, wing, outline, fill);

    // 몸통
    final torso = Rect.fromCenter(center: Offset(50 * u, 62 * u), width: 44 * u, height: 40 * u);
    canvas.drawOval(torso, fill..color = body);
    canvas.drawOval(torso, outline);
    // 배
    canvas.drawOval(Rect.fromCenter(center: Offset(46 * u, 66 * u), width: 26 * u, height: 26 * u), fill..color = belly);

    // 다리·발
    for (final dx in [36.0, 58.0]) {
      final foot = Rect.fromCenter(center: Offset(dx * u, 82 * u), width: 16 * u, height: 10 * u);
      canvas.drawOval(foot, fill..color = body);
      canvas.drawOval(foot, outline);
    }

    // 머리
    final head = Rect.fromCenter(center: Offset(40 * u, 36 * u), width: 40 * u, height: 36 * u);
    // 뿔
    for (final (dx, dir) in [(28.0, -1.0), (50.0, 1.0)]) {
      final horn = Path()
        ..moveTo(dx * u, 22 * u)
        ..lineTo((dx + dir * 6) * u, 8 * u)
        ..lineTo((dx + dir * 10) * u, 22 * u)
        ..close();
      canvas.drawPath(horn, fill..color = silhouette ? body : const Color(0xFFF5E6C8));
      canvas.drawPath(horn, outline);
    }
    canvas.drawOval(head, fill..color = body);
    canvas.drawOval(head, outline);
    // 주둥이
    final snout = Rect.fromCenter(center: Offset(26 * u, 42 * u), width: 18 * u, height: 12 * u);
    canvas.drawOval(snout, fill..color = belly);
    canvas.drawOval(snout, outline);
    if (!silhouette) {
      canvas.drawCircle(Offset(22 * u, 40 * u), 1.4 * u, Paint()..color = dark);
      // 볼터치
      canvas.drawOval(
        Rect.fromCenter(center: Offset(48 * u, 44 * u), width: 8 * u, height: 4 * u),
        Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.6),
      );
      // 눈 (깜빡임: 세로 크기 축소)
      final eyeH = 9 * u * (1 - blink * 0.9);
      final eye = Rect.fromCenter(center: Offset(38 * u, 34 * u), width: 9 * u, height: math.max(1.2 * u, eyeH));
      canvas.drawOval(eye, Paint()..color = Colors.white);
      canvas.drawOval(eye, Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 1.6 * u);
      if (blink < 0.6) {
        canvas.drawCircle(Offset(37 * u, 35 * u), 3 * u, Paint()..color = dark);
        canvas.drawCircle(Offset(36 * u, 33.5 * u), 1.1 * u, Paint()..color = Colors.white);
      }
    }

    // 앞날개
    _wing(canvas, u, Offset(54 * u, 48 * u), 0.85, wing, outline, fill);

    if (isBoss && !silhouette) {
      final crown = Path()
        ..moveTo(30 * u, 10 * u)
        ..lineTo(34 * u, 0)
        ..lineTo(40 * u, 8 * u)
        ..lineTo(46 * u, 0)
        ..lineTo(50 * u, 10 * u)
        ..close();
      canvas.drawPath(crown, fill..color = const Color(0xFFFBBF24));
      canvas.drawPath(crown, outline);
    }
  }

  void _wing(Canvas canvas, double u, Offset root, double scale, Color color, Paint outline, Paint fill) {
    final s = scale * u;
    final p = Path()
      ..moveTo(root.dx, root.dy)
      ..cubicTo(root.dx + 10 * s, root.dy - 26 * s, root.dx + 30 * s, root.dy - 30 * s, root.dx + 30 * s, root.dy - 12 * s)
      ..lineTo(root.dx + 22 * s, root.dy - 16 * s)
      ..lineTo(root.dx + 18 * s, root.dy - 4 * s)
      ..lineTo(root.dx + 10 * s, root.dy - 8 * s)
      ..close();
    canvas.drawPath(p, fill..color = color);
    canvas.drawPath(p, outline);
  }

  @override
  bool shouldRepaint(DragonPainter old) =>
      old.monster?.id != monster?.id || old.isBoss != isBoss || old.silhouette != silhouette || old.blink != blink;
}

/// 이름에 '용'이 들어가는 몬스터는 용 형태로 그린다. 형태 다양화의 첫 예외.
bool isDragon(Monster? m) => m != null && (m.name.contains('용') || m.name.contains('룡'));
