import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../domain/balance_config.dart';
import '../../domain/field.dart';
import '../../domain/game_state.dart';
import '../../domain/monster_unit.dart';
import '../../domain/monster.dart';
import '../../domain/number_format.dart';
import '../sprites/monster_sprite.dart' show elementColor, regionColors;
import 'effects.dart';
import 'sheet_loader.dart';
import 'stage_actor.dart';

/// 화면에 반드시 보이는 세계의 크기. 배율은 이 상자를 덮는 최소값이다.
///
/// 이렇게 두면 **캐릭터가 화면 가로에서 차지하는 비율이 창 모양과 무관해진다**.
/// 2026-09-05까지는 무대 전체를 채우는 방식(cover)이라 세로로 긴 창에서 배율이 3.50까지 튀어
/// 보이는 가로가 238로 줄었고, 폭 360인 무대가 아예 안 들어와 캐릭터가 화면 밖으로 나갔다.
///
/// 640은 주인공 28픽셀이 가로에 22.9마리 들어가는 값이다(레퍼런스 실측 25~30마리).
/// 480은 4:3 창까지 가로가 배율을 정하게 하는 값이다. 그보다 세로로 긴 창은 지원 범위 밖이다.
const viewWidth = 640.0;
const viewHeight = 480.0;

/// 카메라가 안 움직이는 상자의 반지름. 보이는 가로 640의 25%다.
///
/// 주인공이 이 안에서 움직이면 카메라가 가만히 있고, 벗어나면 맵이 같이 밀린다.
/// 붙어 따라다니면 걸음마다 배경이 흔들려 어지럽다.
const cameraDeadZone = 80.0;

/// 먼 겹이 흐르는 속도. 1이면 카메라와 같이 붙어 움직여 평면으로 보인다.
const farParallax = 0.35;

/// 지역별로 준비된 몬스터 기본 형태 수. 없는 지역은 숲 시트를 색만 바꿔 쓴다.
const _sheetsPerRegion = <String, int>{'forest': 2};

const _heroSheetId = 'warrior_1';
const _heroSize = 28;
const _bossSheetId = 'forest';
const _bossSize = 48;
const _monsterSize = 24;
const _petSize = 16;

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
        super(camera: CameraComponent());

  MonsterCatalog catalog;
  BalanceConfig config;

  final SheetLoader _loader;
  final Images _bgImages;
  final _root = PositionComponent();
  final _actors = _ActorLayer();
  final _fx = PositionComponent(priority: 9000);
  late final _bg = _Background(this);
  final _rng = math.Random();

  /// 몬스터 줄. 0번이 지금 싸우는 상대. [_keys]와 자리 번호가 같다.
  final _queue = <StageActor>[];

  /// 줄에 선 몬스터의 상태 번호. 상태의 무리와 맞추는 데 쓴다.
  final _keys = <int>[];
  StageActor? _hero;
  StageActor? _pet;

  /// 조회용(테스트·디버그). 무대 밖에서 상태를 바꾸지 않는다.
  StageActor? get hero => _hero;
  StageActor? get pet => _pet;
  List<StageActor> get monsters => List.unmodifiable(_queue);
  static const monsterPixelSize = _monsterSize;
  static const bossPixelSize = _bossSize;
  static const heroPixelSize = _heroSize;
  static const petPixelSize = _petSize;

  /// [left]~[right] 세계 구간을 덮는 타일들의 왼쪽 x. 타일 폭은 [viewWidth]다.
  ///
  /// [parallax]가 1이면 카메라와 같이 흐르고, 작을수록 천천히 흐른다.
  /// 먼 것이 천천히 지나가야 깊이가 보인다 — 1로 두면 배경이 통째로 붙어 평면이 된다.
  static List<double> backgroundTilesFor(double left, double right, double parallax) {
    // 시차: 겹을 카메라 이동의 (1 - parallax)만큼 되끌어 준다.
    final shift = left * (1 - parallax);
    final first = ((left - shift) / viewWidth).floorToDouble() * viewWidth + shift;
    final out = <double>[];
    for (var x = first; x < right; x += viewWidth) {
      out.add(x);
    }
    return out;
  }

  /// 타일 반전 패리티 — 겹 자체 공간의 타일 번호로 정한다.
  ///
  /// [x]는 [backgroundTilesFor]가 돌려준 화면 좌표, [left]·[parallax]는 그걸 만들 때 쓴
  /// 카메라 왼쪽 끝과 시차다. 같은 겹-공간 점은 카메라가 어디 있어도 패리티가 같아야 한다.
  static bool flippedAt(double x, double left, double parallax) {
    final shift = left * (1 - parallax);
    return ((x - shift) / viewWidth).round().isOdd;
  }

  static const horizon = _Background.horizon;
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

  static final _heroHome = Vector2(0, heroHomeY);

  /// 보이는 상자를 덮는 최소 배율. 1 아래로 내려가지 않는다 —
  /// 1 미만이면 원본 픽셀이 통째로 버려져 계단이 무너진다.
  double get _zoom {
    final vp = camera.viewport.size;
    return math.max(1.0, math.max(vp.x / viewWidth, vp.y / viewHeight));
  }

  @override
  Color backgroundColor() => const Color(0xFF12161A);

  @override
  Future<void> onLoad() async {
    // 가운데를 기준으로 삼아야 따라다니기 좋다.
    camera.viewfinder.anchor = Anchor.center;
    // 첫 프레임이 튀지 않게 제자리를 잡아 둔다. 이후는 _moveCamera가 이어받는다.
    camera.viewfinder.zoom = _zoom;
    // 주인공은 오른쪽으로만 가므로 카메라는 곧 주인공-80에 끌려간다. 시작부터 그 자리에 둔다.
    // 여기서는 heroX=0을 가정한 상수다 — onLoad 시점엔 _hero가 아직 없어 실제 heroX(저장을 읽었으면
    // 0이 아닐 수 있다, C1)를 못 쓴다. 다음 sync()가 즉시 바로잡으므로 첫 프레임만의 문제다.
    camera.viewfinder.position = Vector2(-cameraDeadZone, fieldHeight - camera.viewport.size.y / _zoom / 2);
    await world.add(_root);
    await _root.addAll([_bg, _actors, _fx]);

    _hero = StageActor(
      sheet: await _loader.load('hero', _heroSheetId, size: _heroSize, color: Colors.blue.shade300),
      pixelSize: _heroSize,
      facingRight: true,
      at: _heroHome.clone(),
      walkSpeed: config.heroMoveSpeed * 1.6,
    );
    _pet = StageActor(
      sheet: await _loader.load('pet', 'fire_baby', size: _petSize, color: Colors.deepOrange.shade300),
      pixelSize: _petSize,
      facingRight: true,
      at: _heroHome + Vector2(-12, 6),
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
    _moveCamera();
    if (_floaterCool > 0) _floaterCool -= dt;
    // 펫은 주인공을 따라간다. 주인공과 몬스터의 목표는 도메인이 정한다.
    final hero = _hero;
    if (hero != null) _pet?.target.setValues(hero.pos.x - 13, hero.pos.y + 6);
    for (final c in _fx.children.whereType<Expiring>().toList()) {
      if (c.expired) _fx.remove(c as Component);
    }
    for (final a in _actors.children.whereType<StageActor>().toList()) {
      if (a.expired) _actors.remove(a);
    }
  }

  /// 카메라를 주인공에 붙인다. 불감대 밖으로 나갈 때만 맵이 같이 밀린다.
  ///
  /// 붙어 따라다니면 걸음마다 배경이 흔들린다. 상자 안에서는 주인공만 움직이고
  /// 상자 벽에 닿을 때 비로소 맵이 흐른다. 가장자리에서 멈추는 처리는 없다 — 가로는 끝이 없다.
  void _moveCamera() {
    final target = _cameraTarget;
    if (target == null) return;

    final zoom = _zoom;
    camera.viewfinder.zoom = zoom;

    var camX = camera.viewfinder.position.x;
    final x = target.pos.x;
    if (x > camX + cameraDeadZone) camX = x - cameraDeadZone;
    if (x < camX - cameraDeadZone) camX = x + cameraDeadZone;

    // 세로는 바닥에 붙인다. 땅이 항상 화면 아래에 오고,
    // 세로로 남는 자리는 하늘이 더 보이는 것으로 채워진다.
    final camY = fieldHeight - camera.viewport.size.y / zoom / 2;
    camera.viewfinder.position = Vector2(camX, camY);
  }

  /// 카메라가 따라가는 대상.
  ///
  /// 레퍼런스는 캐릭터가 셋이라 유저가 고른다. 우리는 아직 주인공 하나뿐이라 고를 것이 없다.
  /// 파티가 셋이 되면(백로그 F절) 이 값만 갈아 끼우면 된다.
  StageActor? get _cameraTarget => _hero;

  /// 새 상태를 받아 변화에 맞는 연출을 트리거한다. 매 틱 호출해도 싸다.
  ///
  /// 무리를 번호로 맞춘다. 사라진 번호는 죽는 연출을 하고 새 번호는 걸어 들어온다.
  /// 광역 스킬이 가운데 몬스터만 죽여도 그 자리의 액터만 사라진다.
  void sync(GameState next) {
    if (_hero == null || _busy) return; // onLoad 완료 전에는 무시
    final prev = _last;
    _last = next;

    final region = catalog.regionFor(next.stage)?.id;
    if (region != _bg.region) _bg.setRegion(region, _bgImages);

    if (prev == null) {
      _busy = true;
      _rebuild(next).whenComplete(() => _busy = false);
      return;
    }

    final dealt = _damageDealt(prev, next);
    if (dealt > 0) {
      _strike(dealt, crit: dealt > prev.statsWith(config).attack * 1.5, element: catalog.byId(prev.monsterId)?.element);
    }

    // 번호 구성이 그대로면 체력만 갱신하면 된다.
    final keys = [for (final u in next.wave) u.key];
    if (_listEquals(keys, _keys)) {
      _follow(next);
      return;
    }

    _busy = true;
    _rebuild(next).whenComplete(() => _busy = false);
  }

  /// 이번 틱에 들어간 피해. 살아남은 것의 감소분 + 사라진 것의 남은 체력.
  double _damageDealt(GameState prev, GameState next) {
    final alive = {for (final u in next.wave) u.key: u.hp};
    var total = 0.0;
    for (final u in prev.wave) {
      final now = alive[u.key];
      total += now == null ? u.hp : (u.hp - now);
    }
    return total;
  }

  /// 무대의 줄을 상태의 무리에 맞춘다. 사라진 것은 죽이고 새것은 걸어 들어온다.
  Future<void> _rebuild(GameState s) async {
    final wanted = [for (final u in s.wave) u.key];

    // 1. 사라진 번호를 죽인다.
    for (var i = _keys.length - 1; i >= 0; i--) {
      if (wanted.contains(_keys[i])) continue;
      final dead = _queue.removeAt(i);
      _keys.removeAt(i);
      dead.showHpBar = false;
      dead.die();
      _fx.add(Burst(
        position: dead.pos + Vector2(0, -dead.sizePx * 0.4),
        particle: scatter(
          count: 16,
          color: elementColor(catalog.byId(s.monsterId)?.element ?? MonsterElement.neutral),
          speed: 55, // 스프라이트가 절반이 되어 같이 절반이다(2026-09-06).
          lifespan: 0.6,
        ),
      ));
    }

    // 2. 새 번호를 뒤에 붙인다.
    for (var i = 0; i < s.wave.length; i++) {
      final unit = s.wave[i];
      if (_keys.contains(unit.key)) continue;
      final actor = await _spawn(s, _queue.length, unit);
      if (actor == null) break;
      _keys.add(unit.key);
      _queue.add(actor);
      await _actors.add(actor);
    }

    // 3. 좌표와 체력을 맞춘다. 무리라 모두 체력 바를 보여 준다.
    _follow(s);
  }

  /// 상태의 좌표를 무대 액터의 목표로 밀어 넣는다.
  ///
  /// 누가 어디로 가는지는 전투 규칙(도메인)이 정한다. 무대는 그 자리를 따라갈 뿐이다.
  void _follow(GameState s) {
    final byKey = {for (final u in s.wave) u.key: u};
    for (var i = 0; i < _queue.length; i++) {
      final unit = byKey[_keys[i]];
      if (unit == null) continue;
      _queue[i].target.setValues(unit.x, unit.y);
      _queue[i].showHpBar = true;
      _queue[i].hpRatio = unit.hpRatio;
    }
    final hero = _hero;
    if (hero != null) {
      hero.target.setValues(s.heroX, s.heroY);
      hero.showHpBar = true;
      hero.hpRatio = s.heroHpRatio(config);
      hero.mpRatio = s.heroMpRatio(config);
    }
  }

  /// 무리의 몬스터 하나를 만든다. 보스는 혼자 크게 선다.
  Future<StageActor?> _spawn(GameState s, int index, MonsterUnit unit) async {
    final region = catalog.regionFor(s.stage);
    final m = catalog.byId(unit.id);
    final isBoss = s.isBoss;
    final size = isBoss ? _bossSize : _monsterSize;
    final sheetId = isBoss ? _bossSheetId : monsterSheetIdFor(m, region?.id);
    final sheet = await _loader.load(
      isBoss ? 'boss' : 'monster',
      sheetId,
      size: size,
      color: elementColor(m?.element ?? MonsterElement.neutral),
    );
    // 상태가 정한 자리에서 시작해 상태가 정한 자리로 간다.
    // 따라가는 속도는 도메인 이동 속도보다 넉넉히 잡아 화면이 뒤처지지 않게 한다.
    return StageActor(
      sheet: sheet,
      pixelSize: size,
      facingRight: false,
      at: Vector2(unit.x, unit.y),
      hue: isBoss ? 0 : monsterHueFor(m),
      walkSpeed: config.monsterMoveSpeed * 1.6,
    )
      ..target.setValues(unit.x, unit.y)
      ..hpRatio = unit.hpRatio;
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 한 번의 타격 — 주인공 공격 모션, 참격, 피격, 넉백, 숫자.
  void _strike(double amount, {required bool crit, MonsterElement? element}) {
    final target = _queue.isEmpty ? null : _queue.first;
    _hero?.play('attack');
    if (target == null) return;

    final center = target.pos + Vector2(0, -target.sizePx * 0.45);
    // radius 44/58 → 22/29, thickness 9/13 → 5/7 — 스프라이트가 절반이 되어 같이 절반이다(2026-09-06).
    _fx.add(SlashArc(center: center, radius: crit ? 29 : 22, color: const Color(0xFFB388FF), thickness: crit ? 7 : 5, life: 0.32, spin: -0.5));
    // radius 30/40 → 15/20, thickness 7 → 4, offset (-6,6) → (-3,3) — 스프라이트가 절반이 되어 같이 절반이다(2026-09-06).
    _fx.add(SlashArc(center: center + Vector2(-3, 3), radius: crit ? 20 : 15, color: Colors.white, thickness: 4, life: 0.26, spin: 0.6));

    target.play('hit');
    target.flash();
    target.knockback(crit ? 6 : 3); // knockback 12/6 → 6/3 — 스프라이트가 절반이 되어 같이 절반이다(2026-09-06).

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
      // 오프셋 넷을 절반으로 — 스프라이트가 절반이 되어 같이 절반이다(2026-09-06).
      const fan = [Offset(-17, -2), Offset(-1, -13), Offset(17, 0), Offset(5, 7)];
      _fx.add(DamageText(
        text: formatNumber(amount),
        crit: crit,
        start: target.pos + Vector2(fan[seq].dx + _rng.nextDouble() * 8 - 4, -target.sizePx * 0.8 + fan[seq].dy),
        sizeScale: 0.9 + _rng.nextDouble() * 0.25,
      ));
    }
    _fx.add(ImpactStar(position: center, radius: crit ? 9 : 6)); // radius 17/11 → 9/6 — 스프라이트가 절반이 되어 같이 절반이다(2026-09-06).
    _fx.add(Burst(
      position: center,
      // speed 85/110 → 43/55 — 스프라이트가 절반이 되어 같이 절반이다(2026-09-06).
      particle: scatter(count: crit ? 12 : 7, color: elementColor(element ?? MonsterElement.neutral), speed: 43),
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

/// 배경 — 먼 겹과 땅 겹. 가로로 끝없이 되풀이한다.
///
/// 한 장 걸러 좌우를 뒤집어 붙인다. 지금 그림은 좌우가 안 이어지므로 그냥 늘어놓으면
/// 640마다 이음매가 보인다. 뒤집으면 이음매가 사라지고, 숲이라 뒤집혀도 어색하지 않다.
class _Background extends PositionComponent {
  _Background(this.game) : super(priority: -1000);

  final BattleStageGame game;

  /// 지평선 y. 하늘이 절반을 조금 넘는다 — 3/4 시점에서 땅이 좁으면 전투가 눌린다.
  static const horizon = 250.0;

  final _pixel = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  String? region;
  ui.Image? _far, _ground;
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
      _far = null;
      _ground = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final vp = game.camera.viewport.size;
    final zoom = game.camera.viewfinder.zoom;
    final center = game.camera.viewfinder.position;
    final halfW = vp.x / zoom / 2;
    final left = center.x - halfW;
    final right = center.x + halfW;

    final far = _far, ground = _ground;
    if (far == null || ground == null) {
      _renderGradient(canvas, left, right);
      return;
    }
    // 하늘은 지평선 위 전부, 땅은 지평선 아래 전부. 그림을 늘려 채운다 —
    // 지금 그림(360×110·360×160)은 이 크기가 아니다. 새 타일이 오면 늘리기가 1대1이 된다.
    _tile(canvas, far, BattleStageGame.backgroundTilesFor(left, right, farParallax), 0, horizon, left, farParallax);
    _tile(canvas, ground, BattleStageGame.backgroundTilesFor(left, right, 1.0), horizon, fieldHeight - horizon, left, 1.0);

    final veil = _veil;
    if (veil != null) {
      canvas.drawRect(Rect.fromLTWH(left, 0, right - left, fieldHeight), Paint()..color = veil);
    }
  }

  /// 한 겹을 늘어놓는다. 한 장 걸러 좌우를 뒤집어 이음매를 없앤다.
  void _tile(Canvas canvas, ui.Image image, List<double> xs, double top, double height, double left, double parallax) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    for (final x in xs) {
      final flip = BattleStageGame.flippedAt(x, left, parallax);
      canvas.save();
      if (flip) {
        canvas.translate(x + viewWidth, 0);
        canvas.scale(-1, 1);
        canvas.drawImageRect(image, src, Rect.fromLTWH(0, top, viewWidth, height), _pixel);
      } else {
        canvas.drawImageRect(image, src, Rect.fromLTWH(x, top, viewWidth, height), _pixel);
      }
      canvas.restore();
    }
  }

  void _renderGradient(Canvas canvas, double left, double right) {
    final rect = Rect.fromLTWH(left, 0, right - left, fieldHeight);
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, regionColors(region)),
    );
    canvas.drawRect(
      Rect.fromLTWH(left, horizon, right - left, fieldHeight - horizon),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }
}
