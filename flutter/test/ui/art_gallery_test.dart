import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/ui/sprites/monster_sprite.dart';
import 'package:idle_fantasy/ui/stage/battle_stage_game.dart';

import '../support/catalog.dart';

/// 아트를 PNG로 뽑는다 — 눈으로 확인하기 위한 도구(테스트 겸).
/// 결과: build/art_gallery.png, build/battle_stage.png
void main() {
  testWidgets('도감 스프라이트 갤러리를 PNG로 내보낸다', (tester) async {
    tester.view.physicalSize = const Size(1200, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = loadBundledCatalog();
    final key = GlobalKey();

    await tester.runAsync(() async {
      await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF2D6A4F),
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final id in [1, 5, 13, 21, 34, 46, 60, 67, 76, 90])
                  MonsterSprite(monster: catalog.byId(id), size: 100),
              ],
            ),
          ),
        ),
      ),
      );
      // 도감 스프라이트는 시트를 비동기로 읽는다 — 로드가 끝날 때까지 돌린다.
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/art_gallery.png')..createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      expect(file.lengthSync(), greaterThan(10000));
    });
  });

  testWidgets('전투 무대를 PNG로 내보낸다 — 걸어 들어오는 몬스터·타격', (tester) async {
    tester.view.physicalSize = const Size(360, 270);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const c = BalanceConfig();
    final key = GlobalKey();
    final game = BattleStageGame(catalog: loadBundledCatalog(), config: c);

    Future<void> snap(String name) async {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/$name.png')..createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
        expect(file.lengthSync(), greaterThan(10000), reason: name);
      });
    }

    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: RepaintBoundary(key: key, child: GameWidget(game: game))));
      await game.ready();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      var s = GameState.initial(c);
      game.sync(s);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (var i = 0; i < 240; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      s = s.withFrontHp(s.monsterHp * 0.4);
      game.sync(s);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
    await snap('battle_stage');
  });
}
