import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../../domain/balance_config.dart';
import '../../domain/game_state.dart';
import '../../domain/monster.dart';
import '../../domain/number_format.dart';
import '../sprites/dragon_painter.dart';
import '../sprites/hero_painter.dart';
import '../sprites/monster_sprite.dart';

/// 전투 무대 — Flame 캔버스. 주인공(왼쪽)과 몬스터(오른쪽), 데미지 숫자, 처치 파티클, 보스 등장 흔들림.
///
/// 게임 로직은 없다. 화면 계층이 [sync]로 상태를 밀어 넣으면 변화를 보고 연출만 한다.
/// UI(HP 바·칩·포획 문구)는 Flutter 위젯이 위에 겹쳐 그린다.
class BattleStageGame extends FlameGame {
  BattleStageGame({required this.catalog, required this.config});

  MonsterCatalog catalog;
  BalanceConfig config;

  late final _StageRoot _root = _StageRoot();
  late final _Background _bg = _Background();
  late final HeroActor hero = HeroActor();
  late final MonsterActor monster = MonsterActor();
  GameState? _last;
  final _rng = math.Random();

  @override
  Color backgroundColor() => const Color(0xFF263238);

  @override
  Future<void> onLoad() async {
    await add(_root);
    await _root.add(_bg);
    await _root.add(hero);
    await _root.add(monster);
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 만료된 연출은 여기서 치운다 — 컴포넌트가 update 도중 스스로를 지우면 자식 집합 순회와 충돌한다.
    final expired = _root.children.where((c) => c is _Expiring && (c as _Expiring).expired).toList();
    for (final c in expired) {
      _root.remove(c);
    }
  }

  void _layout() {
    _bg.size = size;
    hero.position = Vector2(size.x * 0.24, size.y * 0.62);
    monster.position = Vector2(size.x * 0.70, size.y * 0.56);
  }

  /// 새 상태를 받아 변화에 맞는 연출을 트리거한다. 매 틱 호출해도 싸다(변화 없으면 아무것도 안 한다).
  void sync(GameState next) {
    final prev = _last;
    _last = next;
    final m = catalog.byId(next.monsterId);
    _bg.region = catalog.regionFor(next.stage)?.id;
    monster.monster = m;
    monster.isBoss = next.isBoss;
    monster.baseSize = next.isBoss ? 132 : 100;
    if (prev == null) {
      monster.appear();
      return;
    }
    final spawned = next.totalKills > prev.totalKills || next.monsterId != prev.monsterId || next.isBoss != prev.isBoss;
    final damage = prev.monsterHp - next.monsterHp;
    if (damage > 0 || spawned) {
      final dealt = spawned && next.totalKills > prev.totalKills ? prev.monsterHp : damage;
      if (dealt > 0) {
        hero.swing();
        final crit = dealt > prev.statsWith(config).attack * 1.5;
        final floaters = _root.children.whereType<FloatingDamage>().toList();
        if (floaters.length >= 6) _root.remove(floaters.first); // 공격속도가 높으면 겹쳐 쌓인다 — 오래된 것부터 치운다
        _root.add(FloatingDamage(
          text: formatNumber(dealt),
          crit: crit,
          start: monster.position + Vector2(_rng.nextDouble() * 120 - 60, _rng.nextDouble() * 50 - monster.baseSize * 0.45),
        ));
      }
    }
    if (spawned) {
      if (next.totalKills > prev.totalKills) _burst(monster.position, m);
      monster.appear();
      if (next.isBoss && !prev.isBoss) _root.shake();
    } else if (damage > 0) {
      monster.hit();
    }
  }

  void _burst(Vector2 at, Monster? m) {
    final color = m == null ? Colors.white : elementColor(m.element);
    _root.add(_Burst(
      position: at,
      particle: Particle.generate(
        count: 14,
        lifespan: 0.6,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          final speed = 80 + _rng.nextDouble() * 120;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * speed,
            acceleration: Vector2(0, 260),
            child: CircleParticle(radius: 2.5 + _rng.nextDouble() * 3, paint: Paint()..color = color),
          );
        },
      ),
    ));
  }
}

/// 수명이 끝나면 [BattleStageGame.update]가 치우는 연출 컴포넌트.
abstract class _Expiring {
  bool get expired;
}

/// 처치 파티클. 스스로 제거하지 않고 [expired]만 올린다.
class _Burst extends ParticleSystemComponent implements _Expiring {
  _Burst({super.position, super.particle});

  @override
  bool get expired => particle?.shouldRemove ?? true;

  @override
  void update(double dt) => particle?.update(dt);
}

/// 모든 액터의 부모. 흔들림은 이 컴포넌트의 position을 흔든다.
class _StageRoot extends PositionComponent {
  double _shakeLeft = 0;
  static const _shakeTime = 0.45;

  void shake() => _shakeLeft = _shakeTime;

  @override
  void update(double dt) {
    super.update(dt);
    if (_shakeLeft <= 0) {
      if (position != Vector2.zero()) position = Vector2.zero();
      return;
    }
    _shakeLeft -= dt;
    final t = 1 - _shakeLeft / _shakeTime;
    final amp = (1 - t) * 10;
    position = Vector2(math.sin(t * math.pi * 8) * amp, math.cos(t * math.pi * 6) * amp * 0.5);
  }
}

class _Background extends PositionComponent {
  String? region;

  @override
  void render(Canvas canvas) {
    final colors = regionColors(region);
    final rect = size.toRect();
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, colors),
    );
    // 바닥 띠 — 액터가 서 있는 지면
    final ground = Rect.fromLTWH(0, size.y * 0.72, size.x, size.y * 0.28);
    canvas.drawRect(ground, Paint()..color = Colors.black.withValues(alpha: 0.18));
  }
}

/// 주인공. 둥실거림 + 검 휘두르기 + 깜빡임.
class HeroActor extends PositionComponent {
  HeroActor() : super(size: Vector2.all(100), anchor: Anchor.center);

  double _t = 0;
  double _swing = 0;
  double _blinkClock = 0;

  void swing() => _swing = 1;

  double get blink {
    final phase = _blinkClock % 3.4;
    return phase > 3.25 ? 1 - ((phase - 3.25) / 0.15 - 0.5).abs() * 2 : 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _blinkClock += dt;
    if (_swing > 0) _swing = math.max(0, _swing - dt * 6);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(0, math.sin(_t * 2.2) * 3);
    HeroPainter(swing: _swing > 0 ? math.sin((1 - _swing) * math.pi) : 0, blink: blink.clamp(0, 1)).paint(canvas, size.toSize());
    canvas.restore();
  }
}

/// 몬스터. 둥실거림 + 피격 움찔 + 등장 팝 + 깜빡임(용).
class MonsterActor extends PositionComponent {
  MonsterActor() : super(size: Vector2.all(100), anchor: Anchor.center);

  Monster? monster;
  bool isBoss = false;
  double baseSize = 100;
  double _t = 0;
  double _hit = 0;
  double _appear = 1;
  double _blinkClock = 0;

  void hit() => _hit = 1;
  void appear() => _appear = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _blinkClock += dt;
    if (_hit > 0) _hit = math.max(0, _hit - dt * 7);
    if (_appear < 1) _appear = math.min(1, _appear + dt * 3.2);
    size = Vector2.all(baseSize);
  }

  @override
  void render(Canvas canvas) {
    final hitT = 1 - _hit;
    final hitScale = 1 - 0.12 * math.sin(hitT * math.pi);
    final appearScale = Curves.easeOutBack.transform(_appear.clamp(0.0, 1.0));
    final shakeX = _hit > 0 ? math.sin(_hit * math.pi * 3) * 6 : 0.0;
    final phase = _blinkClock % 4.1;
    final blink = phase > 3.95 ? 1 - ((phase - 3.95) / 0.15 - 0.5).abs() * 2 : 0.0;

    canvas.save();
    canvas.translate(size.x / 2 + shakeX, size.y / 2 + math.sin(_t * 2.6) * 4);
    canvas.scale(hitScale * appearScale);
    canvas.translate(-size.x / 2, -size.y / 2);
    final flashing = _hit > 0.5;
    // 백플래시는 별도 레이어에 그려야 스프라이트 픽셀에만 칠해진다(배경까지 네모로 하얘지지 않게).
    if (flashing) canvas.saveLayer(size.toRect().inflate(20), Paint());
    if (isDragon(monster)) {
      DragonPainter(monster: monster, isBoss: isBoss, blink: blink.clamp(0, 1)).paint(canvas, size.toSize());
    } else {
      MonsterPainter(monster: monster, isBoss: isBoss, silhouette: false).paint(canvas, size.toSize());
    }
    if (flashing) {
      canvas.drawRect(size.toRect().inflate(20), Paint()..color = Colors.white.withValues(alpha: (_hit - 0.5) * 0.6)..blendMode = BlendMode.srcATop);
      canvas.restore();
    }
    canvas.restore();
  }
}

/// 떠오르는 데미지 숫자.
class FloatingDamage extends PositionComponent implements _Expiring {
  FloatingDamage({required this.text, required this.crit, required Vector2 start})
      : super(position: start.clone(), anchor: Anchor.center);

  final String text;
  final bool crit;
  double _life = 0;
  static const _span = 0.6;

  @override
  bool get expired => _life >= _span;

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    position.y -= dt * 90;
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _span).clamp(0.0, 1.0);
    final alpha = t < 0.7 ? 1.0 : (1 - t) / 0.3;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: (crit ? Colors.amber : Colors.white).withValues(alpha: alpha),
          fontSize: crit ? 26 : 16,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Colors.black.withValues(alpha: alpha * 0.8), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
  }
}
