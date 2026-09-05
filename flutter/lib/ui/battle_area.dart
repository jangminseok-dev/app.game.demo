import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/upgrade.dart';
import 'hud/battle_hud.dart';
import 'hud/hud_metrics.dart';
import 'hud/pixel_ui.dart';
import 'stage/battle_stage_game.dart';

/// 전투 무대 — Flame 캔버스([BattleStageGame]) 위에 픽셀 HUD를 겹친다.
///
/// 게임 상태를 바꾸지 않는다. 상태 변화를 캔버스에 밀어 넣어 연출만 트리거한다.
class BattleArea extends ConsumerStatefulWidget {
  const BattleArea({super.key});

  @override
  ConsumerState<BattleArea> createState() => _BattleAreaState();
}

class _BattleAreaState extends ConsumerState<BattleArea> with SingleTickerProviderStateMixin {
  late final BattleStageGame _game = BattleStageGame(
    catalog: ref.read(monsterCatalogProvider),
    config: ref.read(balanceConfigProvider),
  );
  late final AnimationController _capture =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  String _captureText = '';

  @override
  void dispose() {
    _capture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider, (_, next) => _game.sync(next));
    ref.listen(captureFeedProvider, (_, events) {
      if (events.isEmpty) return;
      final catalog = ref.read(monsterCatalogProvider);
      _captureText = events.map((c) {
        final name = catalog.byId(c.monsterId)?.name ?? '#${c.monsterId}';
        final how = c.byPity ? ' (확정)' : '';
        return c.first ? '$name 도감 등록!$how' : '$name ★${c.stars}$how';
      }).join('\n');
      _capture.forward(from: 0);
      ref.read(captureFeedProvider.notifier).clear();
    });

    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final catalog = ref.watch(monsterCatalogProvider);
    _game
      ..catalog = catalog
      ..config = config;
    final monster = catalog.byId(state.monsterId);

    String captureLine() {
      if (monster == null) return '';
      final stars = state.starsOf(monster.id);
      if (stars >= config.maxStars) return '★$stars 최대';
      final rate = captureRateOf(state.levels, config, state.passives) *
          monster.rarity *
          (state.isBoss ? config.bossCaptureMultiplier : 1) *
          100;
      final progress =
          (state.pity[monster.id] ?? 0) + (state.killLog[monster.id] ?? 0) + (state.bossKillLog[monster.id] ?? 0);
      final left = math.max(0, config.pityThreshold(monster.rarity) - progress);
      final head = stars > 0 ? '★$stars' : '미등록';
      return '$head · ${rate.toStringAsFixed(2)}% · 확정 $left';
    }

    return Stack(
      children: [
        Positioned.fill(child: GameWidget(game: _game)),
        // HUD 셋. 자리는 화면 지도(스펙 2절) — 좌상단 나 · 상단 중앙 지금 상태 · 무대 하단 상대.
        Positioned(left: 6, top: 6, child: IgnorePointer(child: ProfileBadge(state: state, config: config))),
        Positioned(
          left: 0, right: 0, top: 6,
          child: IgnorePointer(
            child: Center(
              child: StageStatus(state: state, config: config, regionName: catalog.regionFor(state.stage)?.name ?? '???'),
            ),
          ),
        ),
        // 하단 5칸 위 15px. textScaler·글꼴 메트릭으로 라벨이 자라도 겹치지 않게.
        Positioned(
          left: 0, right: 0, bottom: bottomBarHeight + 15,
          child: IgnorePointer(
            child: Center(child: MonsterLine(state: state, monster: monster, captureLine: captureLine())),
          ),
        ),
        Positioned.fill(child: IgnorePointer(child: _CaptureBanner(anim: _capture, text: _captureText))),
      ],
    );
  }
}

/// 포획 알림 — 화면 가운데에서 살짝 떠오르며 사라진다.
class _CaptureBanner extends StatelessWidget {
  const _CaptureBanner({required this.anim, required this.text});

  final Animation<double> anim;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        final opacity = t < 0.15 ? t / 0.15 : (t > 0.75 ? (1 - t) / 0.25 : 1.0);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Align(
            alignment: Alignment(0, -0.25 - t * 0.2),
            child: Transform.scale(
              scale: 0.85 + Curves.easeOutBack.transform(t.clamp(0.0, 1.0)) * 0.25,
              child: PixelPanel(
                color: PixelPalette.goldDark,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: PixelText('★ $text', size: 13),
              ),
            ),
          ),
        );
      },
    );
  }
}
