import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/spike/spike_stage_game.dart';

/// 스파이크 무대를 PNG로 뽑는다 — 실기기 없이 배치·피격 순간을 확인하기 위한 도구. 결과: build/spike_*.png
void main() {
  testWidgets('스파이크 무대 캡처: 대기 → 피격 순간', (tester) async {
    tester.view.physicalSize = const Size(360, 270);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final game = SpikeStageGame();

    Future<void> snap(String name) async {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/spike_$name.png')..createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
        expect(file.lengthSync(), greaterThan(10000), reason: name);
      });
    }

    // GameWidget의 로딩 Future(시트 로드)는 실제 비동기라 runAsync 안에서 시간을 흘려야 끝난다.
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: RepaintBoundary(key: key, child: GameWidget(game: game))));
      await game.ready();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
    await snap('idle');
    game.debugStrike(crit: true);
    await tester.runAsync(() async {
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
    await snap('hit');
    await tester.runAsync(() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
    await snap('after_hit');
  });
}
