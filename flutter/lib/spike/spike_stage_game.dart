import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../ui/stage/battle_stage_game.dart' show FloatingDamage;

/// 스파이크 전용 목업. 시트 6개를 360×270 무대에 세우고 자동 공격 루프를 돈다. 버림 코드.
///
/// 판정용: 픽셀 확대 품질, 화풍 일관성, 타격감(히트스톱·백플래시·흔들림·파티클·데미지 숫자), 팔레트 스왑.
class SpikeStageGame extends FlameGame {
  final _images = Images(prefix: 'assets/');
  final _world = World();
  final _root = _ShakeRoot();
  final _actors = _ActorLayer();
  final _rng = math.Random();
  final _pixel = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  final _enemies = <_Actor>[];
  late _Actor _hero;
  double _clock = 0;
  double _hitStop = 0;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    final cam = CameraComponent.withFixedResolution(width: 360, height: 270, world: _world);
    await addAll([_world, cam]);
    await _world.add(_root);

    _root.add(SpriteComponent(sprite: await _sprite('backgrounds/forest/far.png'), position: Vector2.zero(), paint: _pixel));
    _root.add(SpriteComponent(sprite: await _sprite('backgrounds/forest/ground.png'), position: Vector2(0, 110), paint: _pixel));
    _root.add(_actors);

    _hero = await _actor('hero/warrior_1', Vector2(96, 190), facingRight: true);
    _actors.addAll([
      _hero,
      await _actor('pet/fire_baby', Vector2(66, 202), facingRight: true),
    ]);
    for (final (id, pos, hue) in [
      ('monster/forest_1', Vector2(250, 168), 0.0),
      ('monster/forest_2', Vector2(280, 190), 0.0),
      ('monster/forest_1', Vector2(256, 214), 150.0), // 팔레트 스왑 변종
      ('boss/forest', Vector2(316, 200), 0.0),
    ]) {
      final a = await _actor(id, pos, facingRight: false, hue: hue);
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

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitStop > 0) {
      _hitStop -= dt;
      if (_hitStop <= 0) _actors.timeScale = 1;
    }
    _clock += dt;
    if (_clock >= 0.9) {
      _clock = 0;
      _hero.play('attack');
      final target = _enemies[_rng.nextInt(_enemies.length)];
      Future<void>.delayed(const Duration(milliseconds: 250), () => _strike(target));
    }
    for (final c in _root.children.whereType<FloatingDamage>().toList()) {
      if (c.expired) _root.remove(c);
    }
    for (final c in _root.children.whereType<_Burst>().toList()) {
      if (c.expired) _root.remove(c);
    }
  }

  void _strike(_Actor target) {
    final crit = _rng.nextDouble() < 0.3;
    target.play('hit');
    target.flash();
    _hitStop = crit ? 0.08 : 0.05;
    _actors.timeScale = 0;
    _root.shake(crit ? 6 : 3);
    _root.add(FloatingDamage(
      text: crit ? '1.2K' : '553',
      crit: crit,
      start: target.pos + Vector2(_rng.nextDouble() * 20 - 10, -target.sizePx * 0.9),
    ));
    _root.add(_Burst(
      position: target.pos + Vector2(0, -target.sizePx / 2),
      particle: Particle.generate(
        count: 10,
        lifespan: 0.4,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * (60 + _rng.nextDouble() * 60),
            acceleration: Vector2(0, 200),
            child: CircleParticle(radius: 1.5, paint: Paint()..color = Colors.orangeAccent),
          );
        },
      ),
    ));
  }
}

class _Burst extends ParticleSystemComponent {
  _Burst({super.position, super.particle});
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
    position.setValues(math.sin(t * math.pi * 8) * (1 - t) * _amp, 0);
  }
}

class _ActorLayer extends PositionComponent with HasTimeScale {}

class _Actor extends PositionComponent {
  _Actor({required this.image, required this.spec, required this.pos, required bool facingRight, required double hue})
      : sizePx = ((spec['frame'] as List)[0] as num).toDouble(),
        _paint = Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false
          ..colorFilter = hue == 0 ? null : _hueFilter(hue),
        super(anchor: Anchor.bottomCenter) {
    scale.x = facingRight ? 1 : -1;
    size = Vector2.all(sizePx);
  }

  final ui.Image image;
  final Map<String, dynamic> spec;
  final double sizePx;
  final Vector2 pos;
  final Paint _paint;
  late final Map<String, SpriteAnimation> _anims;
  late final SpriteAnimationComponent _sprite;
  double _flash = 0;

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
    _sprite.animation = a; // 새 티커가 만들어진다(처음부터 재생)
    if (!a.loop) _sprite.animationTicker!.onComplete = () => _sprite.animation = _anims['idle'];
  }

  void flash() => _flash = 0.12;

  @override
  void update(double dt) {
    super.update(dt);
    position.setValues(pos.x.roundToDouble(), pos.y.roundToDouble());
    priority = pos.y.round();
    if (_flash > 0) _flash -= dt;
  }

  @override
  void render(Canvas canvas) {
    // 발밑 그림자 — 자식(스프라이트)보다 먼저 그려진다. 좌표계는 좌상단 기준.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(sizePx / 2, sizePx), width: sizePx * 0.6, height: sizePx * 0.16),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
  }

  @override
  void renderTree(Canvas canvas) {
    if (_flash <= 0) {
      super.renderTree(canvas);
      return;
    }
    final rect = Rect.fromLTWH(0, 0, sizePx, sizePx).inflate(4);
    canvas.saveLayer(rect, Paint());
    super.renderTree(canvas);
    canvas.drawRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.7)..blendMode = BlendMode.srcATop);
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
