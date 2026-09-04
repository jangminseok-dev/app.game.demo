import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'sheet_loader.dart';

/// 무대 위 캐릭터 하나. 주인공·펫·몬스터·보스가 전부 이 클래스다 — 차이는 시트·크기·방향뿐.
///
/// 스스로 걸어서 [target]으로 간다. 도착하면 idle, 이동 중이면 walk.
/// 앵커는 발 중앙, 깊이는 발 y.
class StageActor extends PositionComponent {
  StageActor({
    required this.sheet,
    required this.pixelSize,
    required bool facingRight,
    required Vector2 at,
    this.hue = 0,
    this.walkSpeed = 30,
  })  : pos = at.clone(),
        target = at.clone(),
        _facing = facingRight ? 1 : -1,
        _hue = hue == 0 ? null : hueRotation(hue),
        _paint = Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false
          ..colorFilter = hue == 0 ? null : hueRotation(hue),
        super(anchor: Anchor.bottomCenter, size: Vector2.all(pixelSize.toDouble()));

  final LoadedSheet sheet;
  final int pixelSize;
  final double hue;
  final double walkSpeed;

  /// 진짜 위치(실수). [position]은 매 프레임 정수로 반올림된 값.
  final Vector2 pos;

  /// 걸어갈 목적지. 여기 도달하면 idle로 바뀐다.
  final Vector2 target;

  final double _facing;
  final ColorFilter? _hue;
  final Paint _paint;
  late final SpriteAnimationComponent _sprite;
  final _anims = <String, SpriteAnimation>{};

  String _state = 'idle';
  double _flash = 0;
  double _knock = 0, _knockPower = 0;

  /// 이번 프레임의 넉백 변위. HP 바는 이걸 되돌려 자리에 고정한다.
  final _knockOff = Vector2.zero();
  double _fade = 1;
  bool dying = false;

  bool showHpBar = false;
  double hpRatio = 1;

  /// 마력 바. null이면 안 그린다 — 주인공만 쓴다.
  double? mpRatio;

  double get sizePx => pixelSize.toDouble();
  String get state => _state;
  bool get arrived => (pos - target).length < 1.5;

  static const _knockTime = 0.42;

  @override
  Future<void> onLoad() async {
    for (final name in const ['idle', 'walk', 'attack', 'hit', 'death']) {
      _anims[name] = sheet.animation(name, loop: name == 'idle' || name == 'walk');
    }
    _sprite = SpriteAnimationComponent(
      animation: _anims['idle'],
      size: Vector2.all(sizePx),
      position: Vector2(sizePx / 2, sizePx),
      anchor: Anchor.bottomCenter,
      paint: _paint,
    );
    await add(_sprite);
  }

  /// 비루프 동작(attack·hit·death)을 재생한다. 끝나면 idle로 돌아온다(death 제외).
  void play(String name) {
    if (dying) return;
    final a = _anims[name];
    if (a == null) return;
    _state = name;
    _sprite.animation = a;
    if (!a.loop) {
      _sprite.animationTicker!.onComplete = () {
        if (dying) return;
        _state = 'idle';
        _sprite.animation = _anims['idle'];
      };
    }
  }

  void flash() => _flash = 0.12;

  void knockback(double power) {
    _knock = _knockTime;
    _knockPower = power;
  }

  /// 죽는 연출 — 뒤로 크게 날아가며 사라진다. 끝나면 [expired]가 true.
  void die() {
    if (dying) return;
    dying = true;
    _state = 'death';
    final a = _anims['death'];
    if (a != null) _sprite.animation = a;
    knockback(22);
  }

  bool get expired => dying && _fade <= 0;

  @override
  void update(double dt) {
    super.update(dt);

    if (dying) {
      _fade -= dt * 1.6;
      _paint.color = Colors.white.withValues(alpha: _fade.clamp(0, 1));
    } else {
      // 목적지로 걸어간다
      final delta = target - pos;
      if (delta.length > 1.5) {
        final step = math.min(delta.length, walkSpeed * dt);
        pos.add(delta.normalized() * step);
        if (_state != 'walk' && _state != 'attack' && _state != 'hit') play('walk');
      } else if (_state == 'walk') {
        _state = 'idle';
        _sprite.animation = _anims['idle'];
      }
    }

    var offX = 0.0, offY = 0.0, rot = 0.0;
    if (_knock > 0) {
      _knock -= dt;
      final t = (1 - _knock / _knockTime).clamp(0.0, 1.0);
      final curve = dying ? t : math.sin(t * math.pi); // 죽을 때는 돌아오지 않는다
      offX = -_facing * _knockPower * curve;
      offY = -_knockPower * (dying ? 0.3 : 0.55) * curve;
      rot = -_facing * (dying ? 1.6 : 0.5) * curve;
    }
    _knockOff.setValues(offX, offY);
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
      Paint()..color = Colors.black.withValues(alpha: 0.34 * _fade.clamp(0, 1)),
    );
    if (!showHpBar || dying) return;
    // HP 바 — 발밑, 검은 테두리. 넉백의 이동·회전을 모두 되돌려 자리에 고정한다.
    canvas.save();
    canvas.translate(-_knockOff.x, -_knockOff.y);
    canvas.translate(s / 2, s);
    canvas.rotate(-angle);
    canvas.translate(-s / 2, -s);
    const h = 4.0;
    final w = s * 0.62, x = (s - w) / 2, y = s + 3;
    final r = hpRatio.clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(x - 1, y - 1, w + 2, h + 2), Paint()..color = Colors.black.withValues(alpha: 0.9));
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = const Color(0xFF5A5A5A));
    canvas.drawRect(
      Rect.fromLTWH(x, y, w * r, h),
      Paint()..color = r > 0.5 ? const Color(0xFF56D364) : (r > 0.25 ? const Color(0xFFE3B341) : const Color(0xFFE5534B)),
    );
    // 마력 바 — 체력 바 바로 아래 한 줄.
    final mp = mpRatio;
    if (mp != null) {
      const mh = 2.0;
      final my = y + h + 2;
      canvas.drawRect(Rect.fromLTWH(x - 1, my - 1, w + 2, mh + 2), Paint()..color = Colors.black.withValues(alpha: 0.9));
      canvas.drawRect(Rect.fromLTWH(x, my, w, mh), Paint()..color = const Color(0xFF3A3352));
      canvas.drawRect(
        Rect.fromLTWH(x, my, w * mp.clamp(0.0, 1.0), mh),
        Paint()..color = const Color(0xFF63C7FF),
      );
    }
    canvas.restore();
  }
}

/// 색상환 회전 — 팔레트 스왑. 눈·외곽선이 어두우면 거의 그대로 남는다.
ColorFilter hueRotation(double degrees) {
  final r = degrees * math.pi / 180, c = math.cos(r), s = math.sin(r);
  const lr = 0.213, lg = 0.715, lb = 0.072;
  return ColorFilter.matrix([
    lr + c * (1 - lr) - s * lr, lg - c * lg - s * lg, lb - c * lb + s * (1 - lb), 0, 0,
    lr - c * lr + s * 0.143, lg + c * (1 - lg) + s * 0.140, lb - c * lb - s * 0.283, 0, 0,
    lr - c * lr - s * (1 - lr), lg - c * lg + s * lg, lb + c * (1 - lb) + s * lb, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}
