import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 스파이크 전용 목업. 버림 코드.
///
/// 2차: 레퍼런스(99강화 나무몽둥이) 확대 분석에서 나온 다섯 가지를 넣는다 — 전부 코드, 크레딧 0.
/// ① 캐릭터 3~4배 길이의 참격 잔상  ② 넉백(뒤로 밀리며 회전)  ③ 몬스터 상시 HP 바
/// ④ 몬스터 8마리  ⑤ 두꺼운 외곽선 데미지 숫자(크기 랜덤·흩뿌림)
class SpikeStageGame extends FlameGame {
  SpikeStageGame() : super(camera: CameraComponent.withFixedResolution(width: 360, height: 270));

  final _images = Images(prefix: 'assets/');
  final _root = _ShakeRoot();
  final _actors = _ActorLayer();
  final _fx = PositionComponent(priority: 9000); // 이펙트는 액터 위
  final _rng = math.Random();
  final _pixel = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  final _enemies = <_Actor>[];
  late _Actor _hero;
  double _clock = 0;
  double _hitStop = 0;
  double _pendingHit = -1; // 참격이 나간 뒤 실제 타격까지의 지연
  List<_Actor> _pendingTargets = const [];

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    await world.add(_root);

    _root.add(SpriteComponent(sprite: await _sprite('backgrounds/forest/far.png'), position: Vector2.zero(), paint: _pixel));
    _root.add(SpriteComponent(sprite: await _sprite('backgrounds/forest/ground.png'), position: Vector2(0, 110), paint: _pixel));
    _root.add(_actors);
    _root.add(_fx);

    _hero = await _actor('hero/warrior_1', Vector2(118, 198), facingRight: true);
    _actors.addAll([
      _hero,
      await _actor('pet/fire_baby', Vector2(88, 212), facingRight: true),
      await _actor('hero/warrior_2', Vector2(92, 176), facingRight: true),
    ]);

    // ④ 몬스터 8마리 — 앞뒤로 어긋나게, 색 변종 섞어서
    const layout = [
      ('monster/forest_1', 168.0, 166.0, 0.0),
      ('monster/forest_2', 200.0, 186.0, 0.0),
      ('monster/forest_1', 176.0, 208.0, 150.0),
      ('monster/forest_2', 226.0, 210.0, 60.0),
      ('monster/forest_1', 208.0, 232.0, 220.0),
      ('monster/forest_2', 246.0, 168.0, 300.0),
      ('monster/forest_1', 254.0, 240.0, 0.0),
      ('boss/forest', 296.0, 206.0, 0.0),
    ];
    for (final (id, x, y, hue) in layout) {
      final a = await _actor(id, Vector2(x, y), facingRight: false, hue: hue);
      a.showHpBar = true;
      a.hpRatio = 0.35 + _rng.nextDouble() * 0.65;
      _enemies.add(a);
      _actors.add(a);
    }
  }

  Future<Sprite> _sprite(String path) async => Sprite(await _images.load(path));

  Future<_Actor> _actor(String id, Vector2 pos, {required bool facingRight, double hue = 0}) async {
    final image = await _images.load('sprites/$id.png');
    final spec = jsonDecode(await rootBundle.loadString('assets/sprites/$id.json')) as Map<String, dynamic>;
    return _Actor(image: image, spec: spec, pos: pos, facingRight: facingRight, hue: hue);
  }

  bool? _forceCrit;

  /// 캡처용: 참격 + 타격을 같은 프레임에.
  void debugStrike({bool crit = true}) {
    _swing(forceCrit: crit);
    for (final t in _pendingTargets) {
      _hit(t, crit);
    }
    _pendingTargets = const [];
    _pendingHit = -1;
    _forceCrit = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitStop > 0) {
      _hitStop -= dt;
      if (_hitStop <= 0) _actors.timeScale = 1;
    }
    if (_pendingHit >= 0) {
      _pendingHit -= dt;
      if (_pendingHit < 0) {
        for (final t in _pendingTargets) {
          _hit(t, _forceCrit ?? _rng.nextDouble() < 0.35);
        }
        _pendingTargets = const [];
        _forceCrit = null;
      }
    }
    _clock += dt;
    if (_clock >= 1.1) {
      _clock = 0;
      _swing();
    }
    for (final c in _fx.children.whereType<_Expiring>().toList()) {
      if (c.expired) _fx.remove(c as Component);
    }
  }

  /// 한 번의 공격: 참격 잔상 → 대상 3~5마리에 피격·넉백·숫자.
  void _swing({bool? forceCrit}) {
    _hero.play('attack');
    final targets = (_enemies.toList()..shuffle(_rng)).take(3 + _rng.nextInt(3)).toList();
    final center = targets.fold(Vector2.zero(), (a, b) => a + b.pos) / targets.length.toDouble();

    // ① 참격 잔상 — 무리 전체를 가로지르는 큰 호 하나 + 대상마다 작은 호
    _fx.add(_SlashArc(center: center + Vector2(0, -22), radius: 62, color: const Color(0xFFB388FF), thickness: 14, life: 0.36, spin: -0.6));
    _fx.add(_SlashArc(center: center + Vector2(-6, -14), radius: 46, color: Colors.white, thickness: 8, life: 0.28, spin: 0.5));
    for (final t in targets) {
      _fx.add(_SlashArc(
        center: t.pos + Vector2(_rng.nextDouble() * 12 - 6, -t.sizePx * 0.45),
        radius: 26 + _rng.nextDouble() * 14,
        color: const Color(0xFFCE93D8),
        thickness: 7,
        life: 0.26,
        spin: _rng.nextDouble() * 3 - 1.5,
      ));
    }

    _pendingTargets = targets;
    _pendingHit = 0.09;
    _forceCrit = forceCrit;
  }

  void _hit(_Actor target, bool crit) {
    if (isRemoving || !isMounted) return;
    target.play('hit');
    target.flash();
    target.knockback(crit ? 13 : 7); // ② 넉백
    target.hpRatio = (target.hpRatio - (crit ? 0.18 : 0.09)).clamp(0.08, 1.0);

    _hitStop = crit ? 0.09 : 0.05;
    _actors.timeScale = 0;
    _root.shake(crit ? 7 : 3.5);

    // ⑤ 데미지 숫자 — 크기 랜덤·흩뿌림
    _fx.add(_DamageText(
      text: crit ? '${3 + _rng.nextInt(7)}' : '${1 + _rng.nextInt(4)}',
      crit: crit,
      start: target.pos + Vector2(_rng.nextDouble() * 26 - 13, -target.sizePx * 0.75 - _rng.nextDouble() * 14),
      sizeScale: (crit ? 1.35 : 1.0) * (0.85 + _rng.nextDouble() * 0.4),
    ));
    // 별 모양 임팩트 + 파편
    _fx.add(_ImpactStar(position: target.pos + Vector2(0, -target.sizePx * 0.42), radius: crit ? 17 : 11));
    _fx.add(_Burst(
      position: target.pos + Vector2(0, -target.sizePx * 0.4),
      particle: Particle.generate(
        count: crit ? 14 : 8,
        lifespan: 0.42,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * (70 + _rng.nextDouble() * 80),
            acceleration: Vector2(0, 240),
            child: CircleParticle(radius: 1 + _rng.nextDouble() * 1.4, paint: Paint()..color = const Color(0xFFFFC246)),
          );
        },
      ),
    ));
  }
}

abstract class _Expiring {
  bool get expired;
}

/// ① 참격 잔상 — 초승달 호. 굵기가 가운데서 최대인 활 모양으로, 그리면서 사라진다.
class _SlashArc extends PositionComponent implements _Expiring {
  _SlashArc({
    required Vector2 center,
    required this.radius,
    required this.color,
    required this.thickness,
    required this.life,
    required this.spin,
  })  : _start = -0.9 + spin,
        super(position: center.clone(), anchor: Anchor.center, priority: 9500);

  final double radius, thickness, life, spin;
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
    final sweep = Curves.easeOutCubic.transform(math.min(1, p / 0.45)) * 2.5; // 0.45까지 그려지고
    final fade = p < 0.45 ? 1.0 : 1 - (p - 0.45) / 0.55; // 이후 사라진다
    if (sweep <= 0.02) return;

    // 굵기가 중앙에서 최대인 초승달: 바깥 호 → 안쪽 호로 닫는다
    const steps = 22;
    final outer = <Offset>[], inner = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final a = _start + sweep * f;
      final taper = math.sin(f * math.pi); // 끝은 뾰족, 가운데는 두껍게
      final w = thickness * taper;
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
    canvas.drawPath(path, Paint()
      ..color = Colors.white.withValues(alpha: 0.55 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = false);
  }
}

/// 별 모양 임팩트 섬광 — 레퍼런스의 주황 폭발.
class _ImpactStar extends PositionComponent implements _Expiring {
  _ImpactStar({required Vector2 position, required this.radius})
      : super(position: position.clone(), anchor: Anchor.center, priority: 9600);

  final double radius;
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
    canvas.drawPath(path, Paint()..color = const Color(0xFFFF7A2F).withValues(alpha: 0.75 * fade)..isAntiAlias = false);
    canvas.drawCircle(Offset.zero, r * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.8 * fade)..isAntiAlias = false);
  }
}

/// ⑤ 데미지 숫자 — 두꺼운 검은 외곽선 + 노란 그라데이션, 크기 랜덤.
class _DamageText extends PositionComponent implements _Expiring {
  _DamageText({required this.text, required this.crit, required Vector2 start, required this.sizeScale})
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
    position.y -= dt * 26;
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / _life).clamp(0.0, 1.0);
    final alpha = p < 0.72 ? 1.0 : (1 - p) / 0.28;
    final pop = 1 + 0.5 * math.max(0, 1 - p / 0.18); // 튀어나오는 느낌
    final size = (crit ? 17.0 : 13.0) * sizeScale * pop;

    TextPainter make(Paint paint) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              height: 1,
              foreground: paint,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

    // 두꺼운 검은 외곽선 → 노란 채움
    final stroke = make(Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.24
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.black.withValues(alpha: alpha)
      ..isAntiAlias = false);
    final rect = Rect.fromLTWH(0, 0, stroke.width, stroke.height);
    final fill = make(Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [Colors.white.withValues(alpha: alpha), (crit ? const Color(0xFFFFC107) : const Color(0xFFFFE082)).withValues(alpha: alpha)],
      )
      ..isAntiAlias = false);
    final o = Offset(-stroke.width / 2, -stroke.height / 2);
    stroke.paint(canvas, o);
    fill.paint(canvas, o);
  }
}

class _Burst extends ParticleSystemComponent implements _Expiring {
  _Burst({super.position, super.particle}) : super(priority: 9400);
  @override
  bool get expired => particle?.shouldRemove ?? true;
  @override
  void update(double dt) => particle?.update(dt);
}

class _ShakeRoot extends PositionComponent {
  double _left = 0, _amp = 0;
  void shake(double amp) {
    _left = 0.3;
    _amp = amp;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_left <= 0) {
      position.setZero();
      return;
    }
    _left -= dt;
    final t = 1 - _left / 0.3;
    position.setValues(math.sin(t * math.pi * 8) * (1 - t) * _amp, math.cos(t * math.pi * 6) * (1 - t) * _amp * 0.5);
  }
}

class _ActorLayer extends PositionComponent with HasTimeScale {}

class _Actor extends PositionComponent {
  _Actor({required this.image, required this.spec, required this.pos, required bool facingRight, required double hue})
      : sizePx = ((spec['frame'] as List)[0] as num).toDouble(),
        _facing = facingRight ? 1 : -1,
        _hue = hue == 0 ? null : _hueFilter(hue),
        _paint = Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false
          ..colorFilter = hue == 0 ? null : _hueFilter(hue),
        super(anchor: Anchor.bottomCenter) {
    size = Vector2.all(sizePx);
  }

  final ui.Image image;
  final Map<String, dynamic> spec;
  final double sizePx;
  final Vector2 pos;
  final double _facing;
  final ColorFilter? _hue;
  final Paint _paint;
  late final Map<String, SpriteAnimation> _anims;
  late final SpriteAnimationComponent _sprite;
  double _flash = 0;

  /// ③ 상시 HP 바
  bool showHpBar = false;
  double hpRatio = 1;

  // ② 넉백 — 뒤로 밀리며 회전했다가 제자리로 돌아온다.
  double _knock = 0, _knockPower = 0;
  static const _knockTime = 0.42;

  void knockback(double power) {
    _knock = _knockTime;
    _knockPower = power;
  }

  @override
  Future<void> onLoad() async {
    final fps = (spec['fps'] as num).toInt();
    final anims = spec['animations'] as Map<String, dynamic>;
    final total = anims.values.map((r) => (r as List)[1] as int).reduce(math.max) + 1;
    _anims = {
      for (final e in anims.entries)
        e.key: SpriteAnimation.fromFrameData(
          image,
          SpriteAnimationData.range(
            start: (e.value as List)[0] as int,
            end: (e.value as List)[1] as int,
            amount: total,
            stepTimes: List.filled((e.value as List)[1] - (e.value as List)[0] + 1, 1 / fps),
            textureSize: Vector2.all(sizePx),
            loop: e.key == 'idle' || e.key == 'walk',
          ),
        ),
    };
    _sprite = SpriteAnimationComponent(
      animation: _anims['idle'],
      size: Vector2.all(sizePx),
      position: Vector2(sizePx / 2, sizePx),
      anchor: Anchor.bottomCenter,
      paint: _paint,
    );
    add(_sprite);
  }

  void play(String name) {
    final a = _anims[name];
    if (a == null) return;
    _sprite.animation = a;
    if (!a.loop) _sprite.animationTicker!.onComplete = () => _sprite.animation = _anims['idle'];
  }

  void flash() => _flash = 0.12;

  @override
  void update(double dt) {
    super.update(dt);

    // 넉백: 밀렸다가 되돌아오는 궤적 + 회전
    var offX = 0.0, offY = 0.0, rot = 0.0;
    if (_knock > 0) {
      _knock -= dt;
      final t = (1 - _knock / _knockTime).clamp(0.0, 1.0);
      final curve = math.sin(t * math.pi); // 0 → 1 → 0
      offX = -_facing * _knockPower * curve; // 맞은 쪽 반대로
      offY = -_knockPower * 0.55 * curve; // 살짝 떠오른다
      rot = -_facing * 0.5 * curve;
    }
    position.setValues((pos.x + offX).roundToDouble(), (pos.y + offY).roundToDouble());
    angle = rot;
    priority = pos.y.round();
    scale.x = _facing;

    if (_flash > 0) {
      _flash -= dt;
      _paint.colorFilter = _flash > 0
          ? ColorFilter.mode(Colors.white.withValues(alpha: 0.45 * (_flash / 0.12)), BlendMode.srcATop)
          : _hue;
    }
  }

  @override
  void render(Canvas canvas) {
    final s = sizePx;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s / 2, s), width: s * 0.58, height: s * 0.15),
      Paint()..color = Colors.black.withValues(alpha: 0.34),
    );
    if (!showHpBar) return;
    // ③ HP 바 — 발밑, 검은 테두리 + 초록/빨강. 넉백 회전을 되돌려 항상 수평으로 둔다.
    canvas.save();
    canvas.translate(s / 2, s);
    canvas.rotate(-angle);
    canvas.translate(-s / 2, -s);
    const h = 4.0;
    final w = s * 0.62, x = (s - w) / 2, y = s + 3;
    final r = hpRatio.clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(x - 1, y - 1, w + 2, h + 2), Paint()..color = Colors.black.withValues(alpha: 0.9));
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = const Color(0xFF6B6B6B));
    canvas.drawRect(
      Rect.fromLTWH(x, y, w * r, h),
      Paint()..color = r > 0.5 ? const Color(0xFF56D364) : (r > 0.25 ? const Color(0xFFE3B341) : const Color(0xFFE5534B)),
    );
    canvas.restore();
  }
}

ColorFilter _hueFilter(double degrees) {
  final r = degrees * math.pi / 180, c = math.cos(r), s = math.sin(r);
  const lr = 0.213, lg = 0.715, lb = 0.072;
  return ColorFilter.matrix([
    lr + c * (1 - lr) - s * lr, lg - c * lg - s * lg, lb - c * lb + s * (1 - lb), 0, 0,
    lr - c * lr + s * 0.143, lg + c * (1 - lg) + s * 0.140, lb - c * lb - s * 0.283, 0, 0,
    lr - c * lr - s * (1 - lr), lg - c * lg + s * lg, lb + c * (1 - lb) + s * lb, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}
