import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'spike/spike_stage_game.dart';

/// `flutter run -t lib/spike_main.dart` — 아트 스파이크 목업. 무대만 4:3으로 띄운다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          AspectRatio(aspectRatio: 4 / 3, child: GameWidget(game: SpikeStageGame())),
          const Expanded(child: Center(child: Text('스파이크 — 아래는 비어 있음', style: TextStyle(color: Colors.white54)))),
        ]),
      ),
    ),
  ));
}
