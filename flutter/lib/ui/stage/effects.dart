import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// 수명이 끝나면 무대가 치우는 연출 컴포넌트.
abstract class Expiring {
  bool get expired;
}

/// 참격 잔상 — 가운데가 두꺼운 초승달 호. 그려지면서 사라진다.
/// 레퍼런스에서 화면을 가로지르던 보라 궤적에 해당한다.
class SlashArc extends PositionComponent implements Expiring {
  SlashArc({
    required Vector2 center,
    required this.radius,
    required this.color,
    required this.thickness,
    required this.life,
    required double spin,
  })  : _start = -0.9 + spin,
        super(position: center.clone(), anchor: Anchor.center, priority: 9500);

  final double radius, thickness, life;
  final Color color;
  final double _start;
  double _t = 0;

  @override
  bool get expired => _t >= life;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / life).clamp(0.0, 1.0);
    final sweep = Curves.easeOutCubic.transform(math.min(1, p / 0.45)) * 2.5;
    final fade = p < 0.45 ? 1.0 : 1 - (p - 0.45) / 0.55;
    if (sweep <= 0.02) return;

    const steps = 22;
    final outer = <Offset>[], inner = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final a = _start + sweep * f;
      final w = thickness * math.sin(f * math.pi); // 끝은 뾰족, 가운데는 두껍게
      outer.add(Offset(math.cos(a) * (radius + w / 2), math.sin(a) * (radius + w / 2)));
      inner.add(Offset(math.cos(a) * (radius - w / 2), math.sin(a) * (radius - w / 2)));
    }
    final path = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (final o in outer.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    for (final o in inner.reversed) {
      path.lineTo(o.dx, o.dy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.85 * fade)..isAntiAlias = false);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = false,
    );
  }
}

/// 타격 지점의 방사 섬광.
class ImpactStar extends PositionComponent implements Expiring {
  ImpactStar({required Vector2 position, required this.radius, this.color = const Color(0xFFFF7A2F)})
      : super(position: position.clone(), anchor: Anchor.center, priority: 9600);

  final double radius;
  final Color color;
  double _t = 0;
  static const _life = 0.22;

  @override
  bool get expired => _t >= _life;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / _life).clamp(0.0, 1.0);
    final r = radius * Curves.easeOutQuart.transform(p);
    final fade = 1 - p;
    final path = Path();
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final long = i.isEven ? r : r * 0.42;
      final pt = Offset(math.cos(a) * long, math.sin(a) * long);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.75 * fade)..isAntiAlias = false);
    canvas.drawCircle(Offset.zero, r * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.8 * fade)..isAntiAlias = false);
  }
}

/// 떠오르는 데미지 숫자 — 두꺼운 검은 외곽선 + 흰→노랑 그라데이션.
class DamageText extends PositionComponent implements Expiring {
  DamageText({required this.text, required this.crit, required Vector2 start, this.sizeScale = 1})
      : super(position: start.clone(), anchor: Anchor.center, priority: 9700);

  final String text;
  final bool crit;
  final double sizeScale;
  double _t = 0;
  static const _life = 0.75;

  @override
  bool get expired => _t >= _life;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.y -= dt * 30;
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / _life).clamp(0.0, 1.0);
    final alpha = p < 0.72 ? 1.0 : (1 - p) / 0.28;
    // 치명타는 더 크고, 더 세게 튀어나오고, 색과 기울기가 다르다.
    final pop = 1 + (crit ? 0.85 : 0.35) * math.max(0, 1 - p / (crit ? 0.22 : 0.16));
    final size = (crit ? 11.0 : 7.5) * sizeScale * pop;
    final outline = crit ? const Color(0xFF6B1200) : Colors.black;
    final top = crit ? const Color(0xFFFFF3B0) : Colors.white;
    final bottom = crit ? const Color(0xFFFF6A00) : const Color(0xFFCFD8DC);

    TextPainter make(Paint paint) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, height: 1, foreground: paint),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

    final stroke = make(Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * (crit ? 0.28 : 0.22)
      ..strokeJoin = StrokeJoin.round
      ..color = outline.withValues(alpha: alpha)
      ..isAntiAlias = false);
    final rect = Rect.fromLTWH(0, 0, stroke.width, stroke.height);
    final fill = make(Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [top.withValues(alpha: alpha), bottom.withValues(alpha: alpha)],
      )
      ..isAntiAlias = false);
    final o = Offset(-stroke.width / 2, -stroke.height / 2);
    if (crit) {
      canvas.save();
      canvas.rotate(-0.14);
    }
    stroke.paint(canvas, o);
    fill.paint(canvas, o);
    if (crit) canvas.restore();
  }
}

/// 포획·레벨업 같은 알림 배너.
class Burst extends ParticleSystemComponent implements Expiring {
  Burst({super.position, super.particle}) : super(priority: 9400);

  @override
  bool get expired => particle?.shouldRemove ?? true;

  @override
  void update(double dt) => particle?.update(dt);
}

Particle scatter({required int count, required Color color, required double speed, double lifespan = 0.42}) {
  final rng = math.Random();
  return Particle.generate(
    count: count,
    lifespan: lifespan,
    generator: (i) {
      final a = rng.nextDouble() * math.pi * 2;
      return AcceleratedParticle(
        speed: Vector2(math.cos(a), math.sin(a)) * (speed * (0.6 + rng.nextDouble() * 0.8)),
        acceleration: Vector2(0, 240),
        child: CircleParticle(radius: 1 + rng.nextDouble() * 1.4, paint: Paint()..color = color),
      );
    },
  );
}
