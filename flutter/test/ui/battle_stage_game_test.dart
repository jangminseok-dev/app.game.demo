import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/field.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/monster_unit.dart';
import 'package:idle_fantasy/ui/stage/battle_stage_game.dart';
import 'package:idle_fantasy/ui/stage/sheet_loader.dart';
import 'package:idle_fantasy/ui/stage/effects.dart';
import 'package:idle_fantasy/ui/stage/stage_actor.dart';

import '../support/catalog.dart';

/// 에셋 없이 도는 로더 — 전부 대체 실루엣으로 떨어진다.
class _NoAssetLoader extends SheetLoader {
  @override
  Future<LoadedSheet> load(String group, String id, {required int size, required Color color}) async =>
      SheetLoader.fallback(size: size, color: color);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const c = BalanceConfig();

  Future<BattleStageGame> boot() async {
    final game = BattleStageGame(catalog: loadBundledCatalog(), config: c, loader: _NoAssetLoader());
    game.onGameResize(Vector2(360, 270));
    await game.onLoad();
    game.onMount();
    await game.ready();
    game.update(0);
    return game;
  }


  List<StageActor> actorsOf(BattleStageGame g) => g.descendants().whereType<StageActor>().toList();

  /// 시트 로드(비동기)와 컴포넌트 마운트(프레임)가 모두 끝날 때까지 돌린다.
  Future<void> settle(BattleStageGame g, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await Future<void>.delayed(Duration.zero);
      await g.ready();
      g.update(1 / 60);
    }
  }

  Future<BattleStageGame> bootAt(double w, double h) async {
    final game = BattleStageGame(catalog: loadBundledCatalog(), config: c, loader: _NoAssetLoader());
    game.onGameResize(Vector2(w, h));
    await game.onLoad();
    game.onMount();
    await game.ready();
    game.update(0);
    return game;
  }

  group('배율', () {
    test('보이는 상자 640x480을 덮는 최소 배율이다', () async {
      for (final (w, h) in const [(844.0, 390.0), (832.0, 610.0), (1280.0, 800.0)]) {
        final game = await bootAt(w, h);
        game.update(1 / 60);
        expect(
          game.camera.viewfinder.zoom,
          closeTo(max(w / viewWidth, h / viewHeight), 0.001),
          reason: '$w×$h',
        );
      }
    });

    test('배율은 1 아래로 안 내려간다 — 원본 픽셀이 버려진다', () async {
      // 640×480보다 작은 창. 상자를 덮는 배율은 0.625지만 1로 묶여야 한다.
      final game = await bootAt(400, 300);
      game.update(1 / 60);
      expect(game.camera.viewfinder.zoom, 1.0);
    });

    test('주인공이 화면 가로에서 차지하는 비율이 창 모양과 무관하다', () async {
      // 이것이 사용자가 지적한 문제를 그대로 재는 테스트다.
      // 셋 다 4:3보다 가로로 긴 창이라 가로가 배율을 정한다.
      // 4:3보다 세로로 긴 창은 세로가 정하므로 이 목록에 넣으면 안 된다.
      final ratios = <double>[];
      for (final (w, h) in const [(844.0, 390.0), (832.0, 610.0), (1280.0, 800.0)]) {
        final game = await bootAt(w, h);
        game.update(1 / 60);
        ratios.add(BattleStageGame.heroPixelSize * game.camera.viewfinder.zoom / w);
      }
      for (final r in ratios) {
        expect(r, closeTo(0.044, 0.002), reason: '레퍼런스 실측 3.1~4.8% 안이어야 한다: $ratios');
      }
    });
  });

  group('불감대 카메라', () {
    test('주인공이 상자 안에서 움직이면 카메라가 안 움직인다', () async {
      final game = await bootAt(832, 610);
      game.update(1 / 60);
      final before = game.camera.viewfinder.position.x;
      // 시작 카메라가 주인공(0)-80이라 이미 오른쪽 벽에 붙어 있다. 왼쪽으로 옮겨 안 움직임을 잰다.
      game.hero!.pos.x = before + 5;
      game.hero!.target.x = game.hero!.pos.x;
      game.update(1 / 60);
      expect(game.camera.viewfinder.position.x, closeTo(before, 0.01));
    });

    test('상자를 벗어나면 딱 그만큼 밀린다', () async {
      final game = await bootAt(832, 610);
      game.update(1 / 60);
      final before = game.camera.viewfinder.position.x;
      game.hero!.pos.x = before + cameraDeadZone + 40;
      game.hero!.target.x = game.hero!.pos.x;
      game.update(1 / 60);
      expect(
        game.camera.viewfinder.position.x,
        closeTo(game.hero!.pos.x - cameraDeadZone, 0.01),
        reason: '주인공이 상자 오른쪽 벽에 붙어 있어야 한다',
      );
    });

    test('세로는 바닥에 붙는다 — 남는 자리는 하늘이 더 보인다', () async {
      for (final (w, h) in const [(844.0, 390.0), (832.0, 610.0)]) {
        final game = await bootAt(w, h);
        game.update(1 / 60);
        final visibleH = h / game.camera.viewfinder.zoom;
        expect(
          game.camera.viewfinder.position.y,
          closeTo(fieldHeight - visibleH / 2, 0.01),
          reason: '$w×$h — 아래 끝이 무대 바닥(480)에 닿아야 한다',
        );
      }
    });

    test('무리가 걸어 들어오는 동안에도 주인공이 화면 가운데 상자 안에 있다', () async {
      // 사용자가 지적한 "캐릭터가 화면 밖으로 나간다"를 그대로 재는 테스트다.
      // 고치기 전에는 카메라가 무대 가장자리에 묶여 주인공이 상자 밖으로 밀렸다.
      final game = await bootAt(832, 610);
      game.sync(GameState.initial(c));
      await settle(game, frames: 30);
      final camX = game.camera.viewfinder.position.x;
      expect((game.hero!.pos.x - camX).abs(), lessThanOrEqualTo(cameraDeadZone + 1),
          reason: '주인공 ${game.hero!.pos.x}, 카메라 $camX');
    });

    test('주인공이 아무리 멀리 가도 카메라가 따라간다 — 가장자리가 없다', () async {
      final game = await bootAt(832, 610);
      game.update(1 / 60);
      game.hero!.pos.x = 10000;
      game.hero!.target.x = 10000;
      game.update(1 / 60);
      expect(game.camera.viewfinder.position.x, closeTo(10000 - cameraDeadZone, 0.01));
    });

    test('시작 카메라는 주인공-80이다 — 첫 무리가 화면 밖에서 들어온다', () async {
      final game = await bootAt(832, 610);
      game.update(1 / 60);
      expect(game.camera.viewfinder.position.x, closeTo(-cameraDeadZone, 0.01));
      final rightEdge = game.camera.viewfinder.position.x + 832 / game.camera.viewfinder.zoom / 2;
      expect(rightEdge, lessThan(spawnAheadOfHero), reason: '나타나는 자리($spawnAheadOfHero)가 보이는 끝($rightEdge) 바깥이어야 한다');
    });
  });

  test('무대가 뜨면 주인공과 펫이 서 있다', () async {
    final game = await boot();
    expect(actorsOf(game).length, 2, reason: '주인공 + 펫');
  });

  test('첫 상태를 밀어 넣으면 몬스터가 오른쪽 밖에서 걸어 들어온다', () async {
    final game = await boot();
    game.sync(GameState.initial(c));
    await settle(game, frames: 2);

    final monsters = game.monsters;
    expect(monsters, isNotEmpty);
    for (final m in monsters) {
      expect(m.pos.x, greaterThanOrEqualTo(spawnAheadOfHero), reason: '화면 밖에서 시작');
    }
  });

  test('전투가 돌면 서로 다가가 붙는다', () async {
    final game = await boot();
    const engine = BattleEngine(c);
    final rng = Random(1);
    var s = GameState.initial(c);
    game.sync(s);
    await settle(game);
    // 도메인이 좌표를 정하고 무대가 따라간다.
    // spawnAheadOfHero가 260으로 줄어 240틱쯤에는 무리가 막 한 마리로 줄어드는 경계에 걸린다 —
    // 무리가 둘 이상 남아 있는 동안에 스냅샷을 뜨도록 200틱으로 당긴다.
    for (var i = 0; i < 200; i++) {
      s = engine.tick(s, 1 / 60, rng);
      game.sync(s);
      await Future<void>.delayed(Duration.zero);
      await game.ready();
      game.update(1 / 60);
    }
    final hero = game.hero!;
    final withBars = game.monsters.where((a) => a.showHpBar).toList();
    expect(withBars.length, game.monsters.length, reason: '무리라 모두 HP 바를 단다');
    expect(withBars.length, greaterThan(1), reason: '일반 전투는 무리로 나온다');
    expect(hero.pos.x, greaterThan(0), reason: '집에서 앞으로 나왔다');
    for (final m in game.monsters) {
      expect(
        m.pos.x,
        lessThan(game.camera.viewfinder.position.x + game.camera.viewport.size.x / game.camera.viewfinder.zoom / 2),
        reason: '화면 안으로 들어왔다',
      );
    }
  });

  test('피격·처치·보스 등장을 예외 없이 연출한다', () async {
    final game = await boot();
    var s = GameState.initial(c);
    game.sync(s);
    await settle(game);
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
    }

    s = s.withFrontHp(s.monsterHp - 10); // 피격
    game.sync(s);
    await settle(game, frames: 2);
    expect(game.descendants().whereType<DamageText>(), isNotEmpty);

    s = s.copyWith(
      wave: const [MonsterUnit(key: 9, id: 2, hp: 30, maxHp: 30, x: 20, y: heroHomeY)],
      totalKills: 1,
    ); // 처치
    game.sync(s);
    await settle(game, frames: 3);
    expect(actorsOf(game).where((a) => a.dying), isNotEmpty);

    s = s.copyWith(
      isBoss: true,
      wave: const [MonsterUnit(key: 20, id: 2, hp: 500, maxHp: 500, x: 20, y: heroHomeY)],
    ); // 보스
    game.sync(s);
    await settle(game);
    expect(
      game.monsters.any((a) => a.pixelSize == BattleStageGame.bossPixelSize),
      isTrue,
      reason: '보스는 일반 몬스터보다 크다',
    );

    for (var i = 0; i < 60 * 4; i++) {
      game.update(1 / 60);
    }
    expect(game.descendants().whereType<DamageText>(), isEmpty, reason: '연출은 수명이 끝나면 치워진다');
  });

}
