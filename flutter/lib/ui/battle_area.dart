import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/codex.dart';
import '../domain/number_format.dart';
import '../domain/upgrade.dart';
import 'stage/battle_stage_game.dart';

/// 전투 무대 — Flame 캔버스([BattleStageGame]) 위에 Flutter 위젯 UI(칩·HP 바·포획 문구·포획 연출)를 겹친다.
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
  late final AnimationController _capture = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
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
    final region = catalog.regionFor(state.stage);
    final hpRatio = state.monsterMaxHp == 0 ? 0.0 : (state.monsterHp / state.monsterMaxHp).clamp(0.0, 1.0);

    String captureLine() {
      if (monster == null) return '';
      final stars = state.starsOf(monster.id);
      if (stars >= config.maxStars) return '도감 ★$stars (최대)';
      final rate = captureRateOf(state.levels, config, state.passives) *
          monster.rarity *
          (state.isBoss ? config.bossCaptureMultiplier : 1) *
          100;
      final progress = (state.pity[monster.id] ?? 0) + (state.killLog[monster.id] ?? 0) + (state.bossKillLog[monster.id] ?? 0);
      final left = math.max(0, config.pityThreshold(monster.rarity) - progress);
      final head = stars > 0 ? '도감 ★$stars' : '미등록';
      return '$head · 포획 ${rate.toStringAsFixed(2)}% · 확정까지 $left마리';
    }

    return Stack(
      children: [
        Positioned.fill(child: GameWidget(game: _game)),
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: Row(
            children: [
              _Chip(text: region?.name ?? '???'),
              const Spacer(),
              if (state.isBoss)
                _Chip(text: '보스  ${state.bossTimeLeft.toStringAsFixed(1)}초', color: Colors.red.shade700)
              else
                _Chip(text: '${state.killsOnStage}/${config.killsPerStage}'),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                monster == null ? '몬스터' : '${monster.name}  [${monster.element.label}]',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: hpRatio,
                  minHeight: 10,
                  backgroundColor: Colors.black38,
                  color: state.isBoss ? Colors.red.shade400 : Colors.greenAccent.shade400,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'HP ${formatNumber(state.monsterHp)} / ${formatNumber(state.monsterMaxHp)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(captureLine(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _capture,
              builder: (context, _) {
                final t = _capture.value;
                if (t == 0 || t == 1) return const SizedBox.shrink();
                final opacity = t < 0.15 ? t / 0.15 : (t > 0.75 ? (1 - t) / 0.25 : 1.0);
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Align(
                    alignment: Alignment(0, -0.35 - t * 0.2),
                    child: Transform.scale(
                      scale: 0.8 + Curves.easeOutBack.transform(t.clamp(0.0, 1.0)) * 0.3,
                      child: _Chip(text: '★ $_captureText', color: Colors.amber.shade700, big: true),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.color, this.big = false});
  final String text;
  final Color? color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 16 : 10, vertical: big ? 10 : 5),
      decoration: BoxDecoration(color: color ?? Colors.black45, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: big ? 16 : 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 포획 이벤트 텍스트(테스트용 노출).
String captureLine(CaptureEvent c, String name) => c.first ? '$name 도감 등록!' : '$name ★${c.stars}';
