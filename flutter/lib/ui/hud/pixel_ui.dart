import 'package:flutter/material.dart';

/// 픽셀 UI 공통 스타일. 이미지 에셋 없이 코드로만 그린다.
///
/// 규칙: 각진 모서리, 두꺼운 어두운 테두리, 위쪽 밝은 하이라이트 한 줄.
/// 무대가 픽셀아트라 UI도 안티에일리어싱 없는 직선으로 맞춘다.
class PixelPalette {
  static const ink = Color(0xFF1A1420); // 테두리·글자 외곽
  static const panel = Color(0xFF2E2536); // 패널 바탕
  static const panelLight = Color(0xFF3E3348); // 하이라이트
  static const gold = Color(0xFFFFC24A);
  static const goldDark = Color(0xFFC98A16);
  static const gem = Color(0xFF63C7FF);
  static const hp = Color(0xFF56D364);
  static const hpLow = Color(0xFFE5534B);
  static const boss = Color(0xFFE5534B);
  static const text = Color(0xFFF2ECF7);
  static const textDim = Color(0xFFB4A8C0);
}

/// 각진 픽셀 패널. 테두리 2겹 + 위쪽 하이라이트.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.color = PixelPalette.panel,
    this.border = PixelPalette.ink,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: border, width: 2),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// 외곽선이 있는 픽셀 글자. 배경 위에서도 읽힌다.
class PixelText extends StatelessWidget {
  const PixelText(
    this.text, {
    super.key,
    this.size = 11,
    this.color = PixelPalette.text,
    this.outline = PixelPalette.ink,
    this.weight = FontWeight.w800,
  });

  final String text;
  final double size;
  final Color color;
  final Color outline;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            height: 1.1,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..strokeJoin = StrokeJoin.round
              ..color = outline,
          ),
        ),
        Text(text, style: TextStyle(fontSize: size, fontWeight: weight, height: 1.1, color: color)),
      ],
    );
  }
}

/// 각진 게이지. 채움 위에 밝은 줄 하나로 입체감만 준다.
class PixelGauge extends StatelessWidget {
  const PixelGauge({
    super.key,
    required this.value,
    required this.color,
    this.height = 10,
    this.background = const Color(0xFF1D1724),
  });

  final double value;
  final Color color;
  final double height;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _GaugePainter(value.clamp(0, 1), color, background), size: Size.infinite),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.value, this.color, this.background);

  final double value;
  final Color color, background;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    canvas.drawRect(Offset.zero & size, p..color = PixelPalette.ink);
    final inner = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawRect(inner, p..color = background);
    if (value <= 0) return;
    final fill = Rect.fromLTWH(inner.left, inner.top, inner.width * value, inner.height);
    canvas.drawRect(fill, p..color = color);
    // 위쪽 밝은 줄
    canvas.drawRect(
      Rect.fromLTWH(fill.left, fill.top, fill.width, 2),
      p..color = Color.lerp(color, Colors.white, 0.45)!,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value || old.color != color;
}

/// 재화 표시 — 아이콘(마름모/동전) + 숫자.
class CurrencyChip extends StatelessWidget {
  const CurrencyChip({super.key, required this.amount, required this.color, this.gem = false});

  final String amount;
  final Color color;

  /// true면 마름모(보석), false면 원형(동전).
  final bool gem;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 14, height: 14, child: CustomPaint(painter: _CoinPainter(color, gem))),
          const SizedBox(width: 5),
          PixelText(amount, size: 11),
        ],
      ),
    );
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter(this.color, this.gem);

  final Color color;
  final bool gem;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.42;
    final fill = Paint()
      ..isAntiAlias = false
      ..color = color;
    final edge = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = PixelPalette.ink;
    if (gem) {
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r, c.dy)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    } else {
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, edge);
      canvas.drawCircle(c.translate(-r * 0.25, -r * 0.25), r * 0.28, Paint()..color = Colors.white54);
    }
  }

  @override
  bool shouldRepaint(_CoinPainter old) => old.color != color || old.gem != gem;
}
