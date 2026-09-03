import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/ui/sprites/dragon_painter.dart';
import 'package:idle_fantasy/ui/sprites/hero_painter.dart';
import 'package:idle_fantasy/ui/stage/battle_stage_game.dart';

import '../support/catalog.dart';

void main() {
  const c = BalanceConfig();

  Future<BattleStageGame> boot() async {
    final game = BattleStageGame(catalog: loadBundledCatalog(), config: c);
    game.onGameResize(Vector2(400, 300));
    await game.onLoad();
    game.onMount();
    game.update(0);
    return game;
  }

  test('무대가 뜨고 상태를 밀어 넣으면 액터가 배치된다', () async {
    final game = await boot();
    game.sync(GameState.initial(c));
    expect(game.hero.position.x, lessThan(game.monster.position.x), reason: '주인공 왼쪽, 몬스터 오른쪽');
    expect(game.monster.monster!.id, 1);
    expect(game.monster.isBoss, false);
  });

  test('피격·처치·보스 등장을 연출로 옮긴다 (예외 없이 업데이트)', () async {
    final game = await boot();
    var s = GameState.initial(c);
    game.sync(s);
    s = s.copyWith(monsterHp: s.monsterHp - 10); // 피격
    game.sync(s);
    s = s.copyWith(monsterHp: 30, monsterMaxHp: 30, totalKills: 1, monsterId: 2); // 처치 → 다음 몬스터
    game.sync(s);
    s = s.copyWith(isBoss: true, bossTimeLeft: 30, monsterId: 2); // 보스 등장 → 흔들림
    game.sync(s);
    expect(game.monster.isBoss, true);
    expect(game.monster.baseSize, greaterThan(100));
    for (var i = 0; i < 60; i++) {
      game.update(1 / 60);
    }
    // 1초 뒤에는 데미지 숫자(0.75s)·파티클(0.6s)이 전부 치워져 액터 3개(배경·주인공·몬스터)만 남는다
    expect(game.hero.parent!.children.length, 3);
  });

  testWidgets('용 이름 몬스터는 용 페인터로 그려지고, 페인터들은 예외 없이 렌더된다', (tester) async {
    final catalog = loadBundledCatalog();
    final dragons = catalog.monsters.where(isDragon).toList();
    expect(dragons.map((m) => m.id), containsAll([30, 80, 99]));
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(children: [
          for (final m in dragons) ...[
            CustomPaint(size: const Size(96, 96), painter: DragonPainter(monster: m)),
            CustomPaint(size: const Size(96, 96), painter: DragonPainter(monster: m, isBoss: true, blink: 0.8)),
          ],
          const CustomPaint(size: Size(96, 96), painter: HeroPainter()),
          const CustomPaint(size: Size(96, 96), painter: HeroPainter(swing: 0.7, blink: 1)),
        ]),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
