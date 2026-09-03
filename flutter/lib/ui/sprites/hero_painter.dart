import 'package:flutter/material.dart';

/// 주인공 — 2등신 카툰 검사. 96×96 기준, 오른쪽(몬스터 쪽)을 본다.
///
/// [swing] 0~1: 검을 휘두르는 정도(공격 연출). [blink] 0~1: 눈 감김.
class HeroPainter extends CustomPainter {
  const HeroPainter({this.swing = 0, this.blink = 0});

  final double swing;
  final double blink;

  static const _skin = Color(0xFFFFD9B3);
  static const _hair = Color(0xFF5B3A1E);
  static const _tunic = Color(0xFF3B82F6);
  static const _tunicDark = Color(0xFF1E40AF);
  static const _steel = Color(0xFFD1D5DB);
  static const _outline = Color(0xFF1F2937);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 96;
    final outline = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * u
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint();

    canvas.drawOval(
      Rect.fromCenter(center: Offset(48 * u, 90 * u), width: 40 * u, height: 8 * u),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // 검 (몸 뒤에서 앞으로 휘두름)
    canvas.save();
    canvas.translate(60 * u, 62 * u);
    canvas.rotate(-1.1 + swing * 1.9);
    final blade = RRect.fromRectAndRadius(Rect.fromLTWH(-2.5 * u, -34 * u, 5 * u, 34 * u), Radius.circular(2 * u));
    canvas.drawRRect(blade, fill..color = _steel);
    canvas.drawRRect(blade, outline);
    canvas.drawRect(Rect.fromLTWH(-7 * u, -2 * u, 14 * u, 3.5 * u), fill..color = const Color(0xFFB45309));
    canvas.drawRect(Rect.fromLTWH(-2 * u, 1.5 * u, 4 * u, 9 * u), fill..color = _hair);
    canvas.restore();

    // 다리
    for (final dx in [40.0, 54.0]) {
      final leg = RRect.fromRectAndRadius(Rect.fromLTWH((dx - 5) * u, 70 * u, 10 * u, 16 * u), Radius.circular(4 * u));
      canvas.drawRRect(leg, fill..color = _tunicDark);
      canvas.drawRRect(leg, outline);
    }
    // 몸통(튜닉)
    final torso = RRect.fromRectAndRadius(Rect.fromLTWH(32 * u, 48 * u, 32 * u, 28 * u), Radius.circular(8 * u));
    canvas.drawRRect(torso, fill..color = _tunic);
    canvas.drawRRect(torso, outline);
    canvas.drawRect(Rect.fromLTWH(34 * u, 62 * u, 28 * u, 4 * u), fill..color = const Color(0xFF92400E));
    // 방패(왼팔)
    final shield = RRect.fromRectAndRadius(Rect.fromLTWH(22 * u, 52 * u, 14 * u, 18 * u), Radius.circular(5 * u));
    canvas.drawRRect(shield, fill..color = const Color(0xFF9CA3AF));
    canvas.drawRRect(shield, outline);
    canvas.drawCircle(Offset(29 * u, 61 * u), 2.5 * u, fill..color = const Color(0xFFFBBF24));

    // 머리
    final head = Rect.fromCenter(center: Offset(48 * u, 32 * u), width: 38 * u, height: 36 * u);
    canvas.drawOval(head, fill..color = _skin);
    canvas.drawOval(head, outline);
    // 머리카락(앞머리 뭉치)
    final hair = Path()
      ..moveTo(30 * u, 30 * u)
      ..cubicTo(28 * u, 10 * u, 68 * u, 10 * u, 66 * u, 30 * u)
      ..lineTo(60 * u, 24 * u)
      ..lineTo(54 * u, 30 * u)
      ..lineTo(48 * u, 22 * u)
      ..lineTo(42 * u, 30 * u)
      ..lineTo(36 * u, 24 * u)
      ..close();
    canvas.drawPath(hair, fill..color = _hair);
    canvas.drawPath(hair, outline);
    // 눈
    final eyeH = 8 * u * (1 - blink * 0.9);
    for (final dx in [43.0, 55.0]) {
      final eye = Rect.fromCenter(center: Offset(dx * u, 36 * u), width: 7 * u, height: eyeH < 1.2 * u ? 1.2 * u : eyeH);
      canvas.drawOval(eye, fill..color = Colors.white);
      canvas.drawOval(eye, Paint()..color = _outline..style = PaintingStyle.stroke..strokeWidth = 1.4 * u);
      if (blink < 0.6) {
        canvas.drawCircle(Offset((dx + 1) * u, 37 * u), 2.4 * u, fill..color = _outline);
        canvas.drawCircle(Offset((dx + 2) * u, 35.8 * u), 0.9 * u, fill..color = Colors.white);
      }
    }
    // 입·볼
    canvas.drawArc(Rect.fromCenter(center: Offset(50 * u, 44 * u), width: 8 * u, height: 5 * u), 0.2, 2.7, false,
        Paint()..color = _outline..style = PaintingStyle.stroke..strokeWidth = 1.4 * u);
    canvas.drawOval(Rect.fromCenter(center: Offset(40 * u, 42 * u), width: 6 * u, height: 3 * u),
        fill..color = const Color(0xFFFF8FA3).withValues(alpha: 0.55));
  }

  @override
  bool shouldRepaint(HeroPainter old) => old.swing != swing || old.blink != blink;
}
