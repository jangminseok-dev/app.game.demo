import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/sprites/dragon_painter.dart';
import 'package:idle_fantasy/ui/sprites/hero_painter.dart';
import 'package:flame/game.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/ui/sprites/monster_sprite.dart';
import 'package:idle_fantasy/ui/stage/battle_stage_game.dart';

import '../support/catalog.dart';

/// 코드 벡터 아트를 PNG로 뽑는다 — 아트 방향을 눈으로 비교하기 위한 도구(테스트 겸).
/// 결과: build/art_gallery.png
void main() {
  testWidgets('벡터 아트 갤러리를 PNG로 내보낸다', (tester) async {
    tester.view.physicalSize = const Size(1200, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = loadBundledCatalog();
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF2D6A4F),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const CustomPaint(size: Size(200, 200), painter: HeroPainter()),
                    const CustomPaint(size: Size(200, 200), painter: HeroPainter(swing: 0.8)),
                    CustomPaint(size: const Size(200, 200), painter: DragonPainter(monster: catalog.byId(30))),
                    CustomPaint(size: const Size(200, 200), painter: DragonPainter(monster: catalog.byId(80), isBoss: true)),
                    CustomPaint(size: const Size(200, 200), painter: DragonPainter(monster: catalog.byId(99), blink: 1)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final id in [1, 5, 13, 21, 34, 46, 60, 67, 76, 90])
                      MonsterSprite(monster: catalog.byId(id), size: 100),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('위: 주인공·아기 용(코드 벡터)   아래: 지역별 기본 형태 + 팔레트 스왑',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/art_gallery.png')..createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      expect(file.lengthSync(), greaterThan(10000));
    });
  });

  test('전투 무대(Flame)를 PNG로 내보낸다 — 주인공·용 보스·데미지·파티클', () async {
    const c = BalanceConfig();
    final game = BattleStageGame(catalog: loadBundledCatalog(), config: c);
    game.onGameResize(Vector2(720, 420));
    await game.onLoad();
    game.onMount();
    game.update(0);
    // 130층 = 화산 용왕(id 30) 보스전 장면
    var s = GameState.initial(c).copyWith(stage: 130, highestStage: 130, monsterId: 30, isBoss: true, bossTimeLeft: 22, monsterHp: 2000, monsterMaxHp: 3000);
    game.sync(s);
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
    }
    s = s.copyWith(monsterHp: 1900); // 피격 → 데미지 숫자·검 휘두름
    game.sync(s);
    for (var i = 0; i < 8; i++) {
      game.update(1 / 60);
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(2);
    game.render(canvas);
    final image = await recorder.endRecording().toImage(1440, 840);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/battle_stage.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(file.lengthSync(), greaterThan(10000));
  });
}
