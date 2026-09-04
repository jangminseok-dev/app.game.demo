import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../domain/balance_config.dart';
import '../../domain/game_state.dart';
import '../../domain/monster.dart';
import '../../domain/number_format.dart';
import '../sprites/monster_sprite.dart' show elementColor, regionColors;
import 'effects.dart';
import 'sheet_loader.dart';
import 'stage_actor.dart';

/// 무대 가상 해상도. 기기 폭에 맞춰 통째로 확대한다.
const stageWidth = 360.0;
const stageHeight = 270.0;

/// 지역별로 준비된 몬스터 기본 형태 수. 없는 지역은 숲 시트를 색만 바꿔 쓴다.
const _sheetsPerRegion = <String, int>{'forest': 2};

/// 배경 에셋이 있는 지역. 나머지는 기존 그라데이션으로 그린다.
/// (Flame의 Images.load는 실패한 Future를 캐시에 남겨 비동기 예외가 새므로, 없는 파일은 아예 요청하지 않는다.)
const _regionsWithBackground = <String>{'forest'};

/// 전투 무대 — Flame 캔버스.
///
/// 게임 로직은 없다. 화면 계층이 [sync]로 상태를 밀어 넣으면 연출만 한다.
/// 몬스터는 오른쪽 밖에서 걸어 들어와 줄을 서고, 주인공은 맨 앞 몬스터를 향해 걸어간다.
/// 처치되면 줄이 한 칸씩 당겨지고 새 몬스터가 걸어 들어온다.
class BattleStageGame extends FlameGame {
  BattleStageGame({required this.catalog, required this.config, SheetLoader? loader, Images? bgImages})
      : _loader = loader ?? SheetLoader(),
        _bgImages = bgImages ?? Images(prefix: 'assets/backgrounds/'),
        super(camera: CameraComponent.withFixedResolution(width: stageWidth, height: stageHeight));

  MonsterCatalog catalog;
  BalanceConfig config;

  final SheetLoader _loader;
  final Images _bgImages;
  final _root = _ShakeRoot();
  final _actors = _ActorLayer();
  final _fx = PositionComponent(priority: 9000);
  final _bg = _Background();
  final _rng = math.Random();

  /// 몬스터 줄. 0번이 지금 싸우는 상대.
  final _queue = <StageActor>[];
  StageActor? _hero;
  StageActor? _pet;
  GameState? _last;
  double _hitStop = 0;
  bool _busy = false;
  int _floaterSeq = 0;

  /// 몬스터가 서는 자리. 0번이 전투 지점.
  static final _slots = [Vector2(196, 198), Vector2(240, 176), Vector2(268, 216), Vector2(304, 190)];
  static final _heroHome = Vector2(76, 198);
  static const _spawnX = 400.0;

  @override
  Color backgroundColor() => const Color(0xFF12161A);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    await world.add(_root);
    await _root.addAll([_bg, _actors, _fx]);

    _hero = StageActor(
      sheet: await _loader.load('hero', 'warrior_1', size: 56, color: Colors.blue.shade300),
      pixelSize: 56,
      facingRight: true,
      at: _heroHome.clone(),
      walkSpeed: 42,
    );
    _pet = StageActor(
      sheet: await _loader.load('pet', 'fire_baby', size: 32, color: Colors.deepOrange.shade300),
      pixelSize: 32,
      facingRight: true,
      at: _heroHome + Vector2(-24, 12),
      walkSpeed: 46,
    );
    await _actors.addAll([_hero!, _pet!]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitStop > 0) {
      _hitStop -= dt;
      if (_hitStop <= 0) _actors.timeScale = 1;
    }
    // 주인공은 맨 앞 몬스터 앞까지 걸어간다. 펫은 주인공을 따라간다.
    final front = _queue.isEmpty ? null : _queue.first;
    final hero = _hero;
    if (hero != null) {
      hero.target.setValues(
        front == null ? _heroHome.x : math.min(front.pos.x - 46, stageWidth * 0.62),
        front == null ? _heroHome.y : front.pos.y + 4,
      );
      _pet?.target.setValues(hero.pos.x - 26, hero.pos.y + 12);
    }
    for (final c in _fx.children.whereType<Expiring>().toList()) {
      if (c.expired) _fx.remove(c as Component);
    }
    for (final a in _actors.children.whereType<StageActor>().toList()) {
      if (a.expired) _actors.remove(a);
    }
  }

  /// 새 상태를 받아 변화에 맞는 연출을 트리거한다. 매 틱 호출해도 싸다.
  void sync(GameState next) {
    if (_hero == null || _busy) return; // onLoad 완료 전에는 무시
    final prev = _last;
    _last = next;

    final region = catalog.regionFor(next.stage)?.id;
    if (region != _bg.region) _bg.setRegion(region, _bgImages);

    if (prev == null) {
      _busy = true;
      _fillQueue(next).whenComplete(() => _busy = false);
      return;
    }

    final spawned = next.totalKills > prev.totalKills || next.monsterId != prev.monsterId || next.isBoss != prev.isBoss;
    final damage = prev.monsterHp - next.monsterHp;
    final dealt = spawned && next.totalKills > prev.totalKills ? prev.monsterHp : damage;

    if (dealt > 0) {
      _strike(dealt, crit: dealt > prev.statsWith(config).attack * 1.5, element: catalog.byId(prev.monsterId)?.element);
    }
    if (!spawned) {
      if (_queue.isNotEmpty && next.monsterMaxHp > 0) {
        _queue.first.hpRatio = (next.monsterHp / next.monsterMaxHp).clamp(0.0, 1.0);
      }
      return;
    }

    _busy = true;
    _advance(next).whenComplete(() => _busy = false);
  }

  /// 맨 앞을 죽이고 줄을 당긴 뒤 새 몬스터를 뒤에 붙인다.
  Future<void> _advance(GameState s) async {
    if (_queue.isNotEmpty) {
      final dead = _queue.removeAt(0);
      dead.showHpBar = false;
      dead.die();
      _fx.add(Burst(
        position: dead.pos + Vector2(0, -dead.sizePx * 0.4),
        particle: scatter(count: 16, color: elementColor(catalog.byId(_last?.monsterId ?? 0)?.element ?? MonsterElement.neutral), speed: 110, lifespan: 0.6),
      ));
    }
    // 보스가 뜨면 줄을 비우고 보스 혼자 세운다
    if (s.isBoss) {
      for (final a in _queue) {
        a.die();
      }
      _queue.clear();
      _root.shake(8);
    }
    for (var i = 0; i < _queue.length; i++) {
      _queue[i].target.setFrom(_slots[i]);
      _queue[i].showHpBar = i == 0;
    }
    await _fillQueue(s);
  }

  /// 줄을 목표 인원까지 채운다. 보스전은 1마리.
  Future<void> _fillQueue(GameState s) async {
    final want = s.isBoss ? 1 : _slots.length;
    while (_queue.length < want) {
      final index = _queue.length;
      final a = await _spawn(s, index);
      if (a == null) break;
      _queue.add(a);
      await _actors.add(a);
    }
    for (var i = 0; i < _queue.length; i++) {
      _queue[i].showHpBar = i == 0;
      if (i == 0 && s.monsterMaxHp > 0) _queue[i].hpRatio = (s.monsterHp / s.monsterMaxHp).clamp(0.0, 1.0);
    }
  }

  /// 줄 뒤쪽 몬스터는 다음 스테이지 몬스터가 아니라 같은 지역에서 아무거나 뽑는다(눈속임).
  Future<StageActor?> _spawn(GameState s, int index) async {
    final region = catalog.regionFor(s.stage);
    Monster? m = index == 0 ? catalog.byId(s.monsterId) : null;
    if (m == null && region != null) {
      final pool = catalog.monstersIn(region.id);
      if (pool.isNotEmpty) m = pool[_rng.nextInt(pool.length)];
    }
    final isBoss = s.isBoss && index == 0;
    final size = isBoss ? 96 : 48;
    final sheetId = isBoss ? 'forest' : _monsterSheet(m, region?.id);
    final sheet = await _loader.load(
      isBoss ? 'boss' : 'monster',
      sheetId,
      size: size,
      color: elementColor(m?.element ?? MonsterElement.neutral),
    );
    final slot = _slots[math.min(index, _slots.length - 1)];
    return StageActor(
      sheet: sheet,
      pixelSize: size,
      facingRight: false,
      at: Vector2(_spawnX + index * 26, slot.y),
      hue: isBoss ? 0 : _monsterHue(m),
      walkSpeed: 30 + _rng.nextDouble() * 8,
    )
      ..target.setFrom(slot)
      ..hpRatio = 1;
  }

  String _monsterSheet(Monster? m, String? regionId) {
    final region = m?.region ?? regionId ?? 'forest';
    final count = _sheetsPerRegion[region];
    if (count == null) return 'forest_${(m?.id ?? 1) % (_sheetsPerRegion['forest'] ?? 1) + 1}'; // 아직 없는 지역은 숲 형태 + 색만
    return '${region}_${(m?.id ?? 1) % count + 1}';
  }

  double _monsterHue(Monster? m) {
    if (m == null) return 0;
    // 같은 형태를 색으로 갈라 변종을 만든다. 속성색을 기준으로 순번만큼 돌린다.
    final base = HSLColor.fromColor(elementColor(m.element)).hue;
    return (base + (m.id % 5) * 24) % 360;
  }

  /// 한 번의 타격 — 주인공 공격 모션, 참격, 피격, 넉백, 숫자.
  void _strike(double amount, {required bool crit, MonsterElement? element}) {
    final target = _queue.isEmpty ? null : _queue.first;
    _hero?.play('attack');
    if (target == null) return;

    final center = target.pos + Vector2(0, -target.sizePx * 0.45);
    _fx.add(SlashArc(center: center, radius: crit ? 58 : 44, color: const Color(0xFFB388FF), thickness: crit ? 13 : 9, life: 0.32, spin: -0.5));
    _fx.add(SlashArc(center: center + Vector2(-6, 6), radius: crit ? 40 : 30, color: Colors.white, thickness: 7, life: 0.26, spin: 0.6));

    target.play('hit');
    target.flash();
    target.knockback(crit ? 12 : 6);

    _hitStop = crit ? 0.08 : 0.045;
    _actors.timeScale = 0;
    _root.shake(crit ? 6.5 : 3);

    final floaters = _fx.children.whereType<DamageText>().toList();
    if (floaters.length >= 5) _fx.remove(floaters.first);
    // 연속 타격이 한 점에 겹치지 않게 순번으로 부채꼴 배치한다.
    final seq = _floaterSeq++ % 5;
    const fan = [Offset(-26, -6), Offset(4, -20), Offset(28, 2), Offset(-8, 10), Offset(16, -12)];
    _fx.add(DamageText(
      text: formatNumber(amount),
      crit: crit,
      start: target.pos +
          Vector2(fan[seq].dx + _rng.nextDouble() * 8 - 4, -target.sizePx * 0.85 + fan[seq].dy),
      sizeScale: 0.9 + _rng.nextDouble() * 0.3,
    ));
    _fx.add(ImpactStar(position: center, radius: crit ? 17 : 11));
    _fx.add(Burst(
      position: center,
      particle: scatter(count: crit ? 12 : 7, color: elementColor(element ?? MonsterElement.neutral), speed: 85),
    ));
  }
}

/// 히트스톱 대상 — 이 레이어의 시간만 멈춘다.
class _ActorLayer extends PositionComponent with HasTimeScale {}

/// 모든 레이어의 부모. 흔들림은 이 컴포넌트의 position을 흔든다.
class _ShakeRoot extends PositionComponent {
  double _left = 0, _amp = 0;
  static const _time = 0.32;

  void shake(double amp) {
    _left = _time;
    _amp = amp;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_left <= 0) {
      if (position != Vector2.zero()) position.setZero();
      return;
    }
    _left -= dt;
    if (_left <= 0) {
      position.setZero();
      return;
    }
    final t = 1 - _left / _time;
    position.setValues(math.sin(t * math.pi * 8) * (1 - t) * _amp, math.cos(t * math.pi * 6) * (1 - t) * _amp * 0.5);
  }
}

/// 배경 원경 + 지면. 에셋이 없는 지역은 기존 그라데이션으로.
class _Background extends PositionComponent {
  _Background() : super(priority: -1000);

  static const horizon = 110.0;

  final _pixel = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  String? region;
  ui.Image? _far, _ground;

  Future<void> setRegion(String? regionId, Images images) async {
    region = regionId;
    _far = null;
    _ground = null;
    if (regionId == null || !_regionsWithBackground.contains(regionId)) return;
    try {
      final far = await images.load('$regionId/far.png');
      final ground = await images.load('$regionId/ground.png');
      if (region == regionId) {
        _far = far;
        _ground = ground;
      }
    } on Object {
      // 아직 배경이 없는 지역 — 그라데이션으로 둔다.
    }
  }

  @override
  void render(Canvas canvas) {
    final far = _far, ground = _ground;
    if (far == null || ground == null) {
      final rect = Rect.fromLTWH(0, 0, stageWidth, stageHeight);
      canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, regionColors(region)));
      canvas.drawRect(
        Rect.fromLTWH(0, horizon, stageWidth, stageHeight - horizon),
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
      return;
    }
    canvas.drawImage(far, Offset.zero, _pixel);
    canvas.drawImage(ground, const Offset(0, horizon), _pixel);
  }
}
