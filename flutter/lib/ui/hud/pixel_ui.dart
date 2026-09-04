import 'package:flutter/material.dart';

/// 픽셀 UI 공통 스타일. 이미지 에셋 없이 코드로만 그린다.
///
/// 규칙: 각진 모서리, 두꺼운 어두운 테두리, 위쪽 밝은 하이라이트 한 줄, 아래 그림자 한 줄.
/// 무대가 픽셀아트라 UI도 안티에일리어싱 없는 직선으로 맞춘다.
///
/// 글꼴은 갈무리(SIL OFL). 시스템 폰트를 쓰면 픽셀 무대 위에서 설정 화면처럼 보인다.
const pixelFont = 'Galmuri';

class PixelPalette {
  // 나무와 금색. 보라·회색은 차갑고 시스템 UI처럼 보인다.
  static const ink = Color(0xFF17110C); // 테두리·글자 외곽
  static const panel = Color(0xFF3A2A1E); // 패널 바탕(짙은 나무)
  static const panelLight = Color(0xFF54402D); // 하이라이트(밝은 나무)
  static const panelDark = Color(0xFF241A12); // 안쪽 그늘
  static const gold = Color(0xFFFFC24A);
  static const goldDark = Color(0xFFB57A17);
  static const gem = Color(0xFF63C7FF);
  static const hp = Color(0xFF56D364);
  static const hpLow = Color(0xFFE5534B);
  static const boss = Color(0xFFE5534B);
  static const text = Color(0xFFF6ECDA);
  static const textDim = Color(0xFFB9A48A);
}

/// 각진 픽셀 패널. 바깥 어두운 테두리 + 안쪽 밝은 윗줄 + 어두운 아랫줄.
///
/// 평평한 사각형은 싸구려로 보인다. 한 픽셀짜리 빗면 두 줄만 넣어도 눌린 나무판처럼 읽힌다.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.color = PixelPalette.panel,
    this.border = PixelPalette.ink,
    this.bevel = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color border;

  /// 빗면을 넣을지. 아주 작은 칩에서는 끄는 편이 깔끔하다.
  final bool bevel;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: border, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 2))],
      ),
      child: bevel
          ? CustomPaint(painter: _BevelPainter(color), child: inner)
          : inner,
    );
  }
}

/// 위 한 줄은 밝게, 아래 한 줄은 어둡게. 빗면 흉내다.
class _BevelPainter extends CustomPainter {
  const _BevelPainter(this.base);

  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    p.color = Color.lerp(base, Colors.white, 0.18)!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 1.5), p);
    p.color = Color.lerp(base, Colors.black, 0.35)!;
    canvas.drawRect(Rect.fromLTWH(0, size.height - 1.5, size.width, 1.5), p);
  }

  @override
  bool shouldRepaint(_BevelPainter old) => old.base != base;
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
            fontFamily: pixelFont,
            fontSize: size,
            fontWeight: weight,
            height: 1.2,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..strokeJoin = StrokeJoin.round
              ..color = outline,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontFamily: pixelFont,
            fontSize: size,
            fontWeight: weight,
            height: 1.2,
            color: color,
          ),
        ),
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
