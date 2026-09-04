import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
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
      expect(m.pos.x, greaterThan(stageWidth), reason: '화면 밖에서 시작');
      expect(m.target.x, lessThan(stageWidth), reason: '화면 안으로 걸어온다');
    }
  });

  test('시간이 흐르면 몬스터가 자리에 도착하고 주인공이 마주 보러 이동한다', () async {
    final game = await boot();
    game.sync(GameState.initial(c));
    await settle(game);
    for (var i = 0; i < 60 * 8; i++) {
      game.update(1 / 60);
    }
    final hero = game.hero!;
    final withBars = game.monsters.where((a) => a.showHpBar).toList();
    expect(withBars.length, game.monsters.length, reason: '무리라 모두 HP 바를 단다');
    expect(withBars.length, greaterThan(1), reason: '일반 전투는 무리로 나온다');
    expect(hero.pos.x, greaterThan(76), reason: '집에서 앞으로 나왔다');
    expect(hero.pos.x, lessThan(game.monsters.first.pos.x), reason: '주인공이 왼쪽');
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
      wave: const [MonsterUnit(key: 9, id: 2, hp: 30, maxHp: 30)],
      totalKills: 1,
    ); // 처치
    game.sync(s);
    await settle(game, frames: 3);
    expect(actorsOf(game).where((a) => a.dying), isNotEmpty);

    s = s.copyWith(
      isBoss: true,
      wave: const [MonsterUnit(key: 20, id: 2, hp: 500, maxHp: 500)],
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
