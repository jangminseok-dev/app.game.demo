import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

import '../../domain/monster.dart';
import '../stage/battle_stage_game.dart' show monsterHueFor, monsterSheetIdFor;
import '../stage/sheet_loader.dart';
import '../stage/stage_actor.dart' show hueRotation;

/// 임시 몬스터 스프라이트 — 코드로 그린다 (7주차 임시 그래픽).
///
/// 규격(GAME_DESIGN 17장 결정): 정사각 96×96 논리 픽셀 기준, 투명 배경, 중앙 정렬.
/// 팔레트 스왑 파이프라인의 검증판이다: 지역마다 기본 형태 1개, 색은 속성 + 몬스터 순번으로 바뀐다.
/// 원화가 들어오면 이 위젯만 PNG 로더로 바꾸고 호출부는 그대로 둔다.
class MonsterSprite extends StatelessWidget {
  const MonsterSprite({
    super.key,
    required this.monster,
    this.size = 96,
    this.isBoss = false,
    this.silhouette = false,
  });

  final Monster? monster;
  final double size;
  final bool isBoss;

  /// 도감 미등록 표시 — 형태만 보이고 색은 가린다.
  final bool silhouette;

  /// 도감·상세에서 쓰는 시트 로더. 무대와 캐시를 나눠 갖는다.
  static final _loader = SheetLoader();

  @override
  Widget build(BuildContext context) {
    final m = monster;
    // 미등록이거나 몬스터가 없으면 형태만 보여 준다(벡터 실루엣).
    if (m == null || silhouette) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: MonsterPainter(monster: m, isBoss: isBoss, silhouette: silhouette)),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<LoadedSheet>(
        future: _loader.load('monster', monsterSheetIdFor(m), size: 48, color: elementColor(m.element)),
        builder: (context, snap) {
          final sheet = snap.data;
          if (sheet == null) return const SizedBox.shrink();
          final (start, _) = sheet.spec.animations['idle']!;
          final f = sheet.spec.frame.toDouble();
          final sprite = Sprite(sheet.image, srcPosition: Vector2(start * f, 0), srcSize: Vector2(f, f));
          final hue = monsterHueFor(m);
          Widget w = SpriteWidget(
            sprite: sprite,
            paint: Paint()
              ..filterQuality = FilterQuality.none
              ..isAntiAlias = false,
          );
          if (hue != 0) w = ColorFiltered(colorFilter: hueRotation(hue), child: w);
          // 무대에서는 왼쪽을 보지만 도감에서는 정면처럼 보이게 그대로 둔다.
          return w;
        },
      ),
    );
  }
}

/// 속성 색. 서비스 팔레트가 정해지면 여기만 바꾼다.
Color elementColor(MonsterElement e) => switch (e) {
      MonsterElement.fire => const Color(0xFFE85D3A),
      MonsterElement.water => const Color(0xFF3B82F6),
      MonsterElement.earth => const Color(0xFF6B8E23),
      MonsterElement.wind => const Color(0xFF2DD4BF),
      MonsterElement.neutral => const Color(0xFF9CA3AF),
    };

/// 지역 배경 그라데이션.
List<Color> regionColors(String? regionId) => switch (regionId) {
      'forest' => const [Color(0xFF1B4332), Color(0xFF2D6A4F)],
      'cave' => const [Color(0xFF1F1B2E), Color(0xFF3A3352)],
      'volcano' => const [Color(0xFF3B0A0A), Color(0xFF7A1F1F)],
      'tundra' => const [Color(0xFF1E3A5F), Color(0xFF5B8DB8)],
      'swamp' => const [Color(0xFF1C2E1A), Color(0xFF4A5D23)],
      'desert' => const [Color(0xFF7A5C1E), Color(0xFFC9A227)],
      'abyss' => const [Color(0xFF020C1B), Color(0xFF0B3D5B)],
      'sky' => const [Color(0xFF4F8FD6), Color(0xFFBFE0FF)],
      'ruins' => const [Color(0xFF2B2B2B), Color(0xFF5C5C5C)],
      'demon' => const [Color(0xFF1A0010), Color(0xFF5A0A2E)],
      _ => const [Color(0xFF263238), Color(0xFF455A64)],
    };

class MonsterPainter extends CustomPainter {
  const MonsterPainter({required this.monster, required this.isBoss, required this.silhouette});

  final Monster? monster;
  final bool isBoss;
  final bool silhouette;

  @override
  void paint(Canvas canvas, Size size) {
    final m = monster;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.34;

    // 팔레트: 속성 기본색을 몬스터 순번(지역 안 0~9)으로 색상환을 살짝 돌려 변종을 만든다.
    final base = m == null ? const Color(0xFF9CA3AF) : elementColor(m.element);
    final variant = m == null ? 0 : (m.id - 1) % 10;
    final hsl = HSLColor.fromColor(base);
    final body = silhouette
        ? const Color(0xFF111827)
        : hsl.withHue((hsl.hue + variant * 9 - 40) % 360).withLightness((hsl.lightness + (variant % 3) * 0.05).clamp(0.2, 0.8)).toColor();
    final dark = HSLColor.fromColor(body).withLightness((HSLColor.fromColor(body).lightness - 0.22).clamp(0.05, 1)).toColor();

    final fill = Paint()..color = body;
    final outline = Paint()
      ..color = silhouette
          ? const Color(0xFF0B1220)
          : isBoss
              ? const Color(0xFFB91C1C)
              : (m != null && m.rarity <= 0.3)
                  ? const Color(0xFFF59E0B) // 희귀: 금색 테두리
                  : dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = isBoss ? 4 : 2.5;

    final path = _shape(m?.region, c, r);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, outline);

    if (!silhouette) {
      // 눈
      final eye = Paint()..color = const Color(0xFF111827);
      final white = Paint()..color = Colors.white;
      final eyeY = c.dy - r * 0.15;
      for (final dx in [-r * 0.32, r * 0.32]) {
        canvas.drawCircle(Offset(c.dx + dx, eyeY), r * 0.16, white);
        canvas.drawCircle(Offset(c.dx + dx + r * 0.04, eyeY), r * 0.08, eye);
      }
      if (isBoss) {
        // 왕관
        final crown = Path()
          ..moveTo(c.dx - r * 0.5, c.dy - r * 0.95)
          ..lineTo(c.dx - r * 0.3, c.dy - r * 1.35)
          ..lineTo(c.dx, c.dy - r * 1.05)
          ..lineTo(c.dx + r * 0.3, c.dy - r * 1.35)
          ..lineTo(c.dx + r * 0.5, c.dy - r * 0.95)
          ..close();
        canvas.drawPath(crown, Paint()..color = const Color(0xFFFBBF24));
      }
    }
  }

  /// 지역별 기본 형태. 지역 하나 = 형태 하나가 팔레트 스왑의 전제다.
  Path _shape(String? region, Offset c, double r) {
    final p = Path();
    switch (region) {
      case 'forest': // 둥근 덩어리
        p.addOval(Rect.fromCircle(center: c, radius: r));
      case 'cave': // 날개 달린 삼각
        p.moveTo(c.dx, c.dy - r);
        p.lineTo(c.dx + r * 1.2, c.dy + r * 0.2);
        p.lineTo(c.dx + r * 0.4, c.dy + r * 0.9);
        p.lineTo(c.dx - r * 0.4, c.dy + r * 0.9);
        p.lineTo(c.dx - r * 1.2, c.dy + r * 0.2);
        p.close();
      case 'volcano': // 불꽃 물방울
        p.moveTo(c.dx, c.dy - r * 1.3);
        p.quadraticBezierTo(c.dx + r * 1.1, c.dy, c.dx, c.dy + r);
        p.quadraticBezierTo(c.dx - r * 1.1, c.dy, c.dx, c.dy - r * 1.3);
        p.close();
      case 'tundra': // 육각 결정
        _polygon(p, c, r * 1.05, 6, math.pi / 6);
      case 'swamp': // 눌린 물방울
        p.addOval(Rect.fromCenter(center: c.translate(0, r * 0.2), width: r * 2.4, height: r * 1.6));
      case 'desert': // 마름모
        _polygon(p, c, r * 1.1, 4, 0);
      case 'abyss': // 물고기
        p.addOval(Rect.fromCenter(center: c, width: r * 2.2, height: r * 1.5));
        p.moveTo(c.dx + r * 0.9, c.dy);
        p.lineTo(c.dx + r * 1.5, c.dy - r * 0.6);
        p.lineTo(c.dx + r * 1.5, c.dy + r * 0.6);
        p.close();
      case 'sky': // 구름
        p.addOval(Rect.fromCircle(center: c.translate(-r * 0.5, r * 0.1), radius: r * 0.7));
        p.addOval(Rect.fromCircle(center: c.translate(r * 0.1, -r * 0.3), radius: r * 0.8));
        p.addOval(Rect.fromCircle(center: c.translate(r * 0.6, r * 0.2), radius: r * 0.6));
      case 'ruins': // 각진 골렘
        p.addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: r * 1.9, height: r * 2), Radius.circular(r * 0.2)));
      case 'demon': // 뿔 달린 원
        p.addOval(Rect.fromCircle(center: c, radius: r));
        p.moveTo(c.dx - r * 0.7, c.dy - r * 0.6);
        p.lineTo(c.dx - r * 0.9, c.dy - r * 1.4);
        p.lineTo(c.dx - r * 0.3, c.dy - r * 0.9);
        p.close();
        p.moveTo(c.dx + r * 0.7, c.dy - r * 0.6);
        p.lineTo(c.dx + r * 0.9, c.dy - r * 1.4);
        p.lineTo(c.dx + r * 0.3, c.dy - r * 0.9);
        p.close();
      default:
        p.addOval(Rect.fromCircle(center: c, radius: r));
    }
    return p;
  }

  static void _polygon(Path p, Offset c, double r, int n, double rot) {
    for (var i = 0; i < n; i++) {
      final a = rot + i * 2 * math.pi / n - math.pi / 2;
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
  }

  @override
  bool shouldRepaint(MonsterPainter old) =>
      old.monster?.id != monster?.id || old.isBoss != isBoss || old.silhouette != silhouette;
}
