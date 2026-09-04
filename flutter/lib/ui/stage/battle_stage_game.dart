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

const _heroSheetId = 'warrior_1';
const _heroSize = 56;
const _bossSheetId = 'forest';
const _bossSize = 96;
const _monsterSize = 48;

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
  final _root = PositionComponent();
  final _actors = _ActorLayer();
  final _fx = PositionComponent(priority: 9000);
  final _bg = _Background();
  final _rng = math.Random();

  /// 몬스터 줄. 0번이 지금 싸우는 상대.
  final _queue = <StageActor>[];
  StageActor? _hero;
  StageActor? _pet;

  /// 조회용(테스트·디버그). 무대 밖에서 상태를 바꾸지 않는다.
  StageActor? get hero => _hero;
  StageActor? get pet => _pet;
  List<StageActor> get monsters => List.unmodifiable(_queue);
  static const monsterPixelSize = _monsterSize;
  static const bossPixelSize = _bossSize;
  GameState? _last;
  double _hitStop = 0;
  bool _busy = false;
  int _floaterSeq = 0;

  /// 데미지 숫자 간격. 공격속도가 초당 15회를 넘어도 화면이 숫자로 덮이지 않게 한다.
  double _floaterCool = 0;

  /// 히트스톱 쿨다운. 공격속도가 초당 9회를 넘어 타격마다 걸면 시간이 계속 멈춘다.
  /// 치명타에만, 그것도 이 간격 이상 떨어져 있을 때만 건다. 화면 흔들림은 쓰지 않는다(어지럽다).
  double _juiceCool = 0;
  static const _juiceGap = 0.55;

  /// 몬스터가 서는 자리. 0번이 전투 지점.
  /// 몬스터가 서는 자리. 0번이 전투 지점. 레퍼런스처럼 화면 전체에 퍼뜨린다.
  static final _slots = [
    Vector2(150, 200),
    Vector2(196, 172),
    Vector2(212, 232),
    Vector2(254, 196),
    Vector2(292, 168),
    Vector2(308, 226),
  ];
  static final _heroHome = Vector2(58, 204);
  static const _spawnX = 400.0;

  @override
  Color backgroundColor() => const Color(0xFF12161A);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    await world.add(_root);
    await _root.addAll([_bg, _actors, _fx]);

    _hero = StageActor(
      sheet: await _loader.load('hero', _heroSheetId, size: _heroSize, color: Colors.blue.shade300),
      pixelSize: _heroSize,
      facingRight: true,
      at: _heroHome.clone(),
      walkSpeed: 90,
    );
    _pet = StageActor(
      sheet: await _loader.load('pet', 'fire_baby', size: 32, color: Colors.deepOrange.shade300),
      pixelSize: 32,
      facingRight: true,
      at: _heroHome + Vector2(-24, 12),
      walkSpeed: 100,
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
    if (_juiceCool > 0) _juiceCool -= dt;
    if (_floaterCool > 0) _floaterCool -= dt;
    // 주인공은 맨 앞 몬스터 앞까지 걸어간다. 펫은 주인공을 따라간다.
    final front = _queue.isEmpty ? null : _queue.first;
    final hero = _hero;
    if (hero != null) {
      hero.target.setValues(
        front == null ? _heroHome.x : math.min(front.pos.x - 34, stageWidth * 0.5),
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
    final size = isBoss ? _bossSize : _monsterSize;
    final sheetId = isBoss ? _bossSheetId : monsterSheetIdFor(m, region?.id);
    final sheet = await _loader.load(
      isBoss ? 'boss' : 'monster',
      sheetId,
      size: size,
      color: elementColor(m?.element ?? MonsterElement.neutral),
    );
    final slot = _slots[math.min(index, _slots.length - 1)];
    final from = Vector2(_spawnX + index * 22, slot.y);
    // 고레벨에서는 몬스터가 3초 안에 죽는다. 거리와 무관하게 약 0.9초에 자리에 닿게 속도를 맞춘다.
    final speed = (from - slot).length / (0.85 + _rng.nextDouble() * 0.25);
    return StageActor(
      sheet: sheet,
      pixelSize: size,
      facingRight: false,
      at: from,
      hue: isBoss ? 0 : monsterHueFor(m),
      walkSpeed: speed,
    )
      ..target.setFrom(slot)
      ..hpRatio = 1;
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

    // 히트스톱은 치명타에만, 쿨다운을 두고 건다.
    if (crit && _juiceCool <= 0) {
      _juiceCool = _juiceGap;
      _hitStop = 0.06;
      _actors.timeScale = 0;
    }

    // 치명타는 항상, 평타는 간격을 두고만 띄운다.
    if (crit || _floaterCool <= 0) {
      _floaterCool = 0.18;
      final floaters = _fx.children.whereType<DamageText>().toList();
      if (floaters.length >= 4) _fx.remove(floaters.first);
      // 연속 타격이 한 점에 겹치지 않게 순번으로 부채꼴 배치한다.
      final seq = _floaterSeq++ % 4;
      const fan = [Offset(-34, -4), Offset(-2, -26), Offset(34, 0), Offset(10, 14)];
      _fx.add(DamageText(
        text: formatNumber(amount),
        crit: crit,
        start: target.pos + Vector2(fan[seq].dx + _rng.nextDouble() * 8 - 4, -target.sizePx * 0.8 + fan[seq].dy),
        sizeScale: 0.9 + _rng.nextDouble() * 0.25,
      ));
    }
    _fx.add(ImpactStar(position: center, radius: crit ? 17 : 11));
    _fx.add(Burst(
      position: center,
      particle: scatter(count: crit ? 12 : 7, color: elementColor(element ?? MonsterElement.neutral), speed: 85),
    ));
  }
}

/// 몬스터 → 시트 id. 지역 안 순번을 기본 형태에 돌려 붙인다.
/// 아직 시트가 없는 지역은 숲 형태를 쓰고 색만 바꾼다([monsterHueFor]).
String monsterSheetIdFor(Monster? m, [String? regionId]) {
  final region = m?.region ?? regionId ?? 'forest';
  final count = _sheetsPerRegion[region] ?? _sheetsPerRegion['forest']!;
  final base = _sheetsPerRegion.containsKey(region) ? region : 'forest';
  return '${base}_${(m?.id ?? 1) % count + 1}';
}

/// 같은 형태를 색으로 갈라 변종을 만든다. 속성색을 기준으로 순번만큼 돌린다.
double monsterHueFor(Monster? m) {
  if (m == null) return 0;
  final base = HSLColor.fromColor(elementColor(m.element)).hue;
  return (base + (m.id % 5) * 24) % 360;
}

/// 히트스톱 대상 — 이 레이어의 시간만 멈춘다.
class _ActorLayer extends PositionComponent with HasTimeScale {}

/// 배경 원경 + 지면. 에셋이 없는 지역은 기존 그라데이션으로.
class _Background extends PositionComponent {
  _Background() : super(priority: -1000);

  static const horizon = 110.0;

  final _pixel = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  String? region;
  ui.Image? _far, _ground;

  /// 전용 배경이 없는 지역은 숲 배경 위에 지역색 덮개를 얹는다.
  Color? _veil;

  Future<void> setRegion(String? regionId, Images images) async {
    region = regionId;
    if (regionId == null) {
      _far = null;
      _ground = null;
      return;
    }
    final own = _regionsWithBackground.contains(regionId);
    try {
      final source = own ? regionId : 'forest';
      final far = await images.load('$source/far.png');
      final ground = await images.load('$source/ground.png');
      if (region != regionId) return;
      _far = far;
      _ground = ground;
      _veil = own ? null : regionColors(regionId).last.withValues(alpha: 0.5);
    } on Object {
      // 숲 배경조차 없으면 그라데이션으로 둔다.
      _far = null;
      _ground = null;
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
    final veil = _veil;
    if (veil != null) canvas.drawRect(Rect.fromLTWH(0, 0, stageWidth, stageHeight), Paint()..color = veil);
  }
}
