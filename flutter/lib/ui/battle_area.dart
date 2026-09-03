import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/codex.dart';
import '../domain/number_format.dart';
import 'sprites/monster_sprite.dart';

/// 전투 무대 — 지역 배경, 몬스터(둥실·피격·등장 연출), HP 바, 보스 타이머, 포획 연출.
///
/// 게임 상태를 바꾸지 않는다. 상태 변화를 보고 연출만 트리거한다.
class BattleArea extends ConsumerStatefulWidget {
  const BattleArea({super.key});

  @override
  ConsumerState<BattleArea> createState() => _BattleAreaState();
}

class _BattleAreaState extends ConsumerState<BattleArea> with TickerProviderStateMixin {
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  late final AnimationController _hit = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
  late final AnimationController _spawn =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  late final AnimationController _capture = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  String _captureText = '';

  @override
  void dispose() {
    _bob.dispose();
    _hit.dispose();
    _spawn.dispose();
    _capture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider, (prev, next) {
      if (prev == null) return;
      if (next.totalKills > prev.totalKills || next.monsterId != prev.monsterId || next.isBoss != prev.isBoss) {
        _spawn.forward(from: 0);
      } else if (next.monsterHp < prev.monsterHp) {
        _hit.forward(from: 0);
      }
    });
    ref.listen(captureFeedProvider, (_, events) {
      if (events.isEmpty) return;
      final catalog = ref.read(monsterCatalogProvider);
      _captureText = events.map((c) {
        final name = catalog.byId(c.monsterId)?.name ?? '#${c.monsterId}';
        return c.first ? '$name 도감 등록!' : '$name ★${c.stars}';
      }).join('\n');
      _capture.forward(from: 0);
      ref.read(captureFeedProvider.notifier).clear();
    });

    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final catalog = ref.watch(monsterCatalogProvider);
    final monster = catalog.byId(state.monsterId);
    final region = catalog.regionFor(state.stage);
    final stats = state.stats;
    final captureChance = monster == null
        ? 0.0
        : stats.captureRate * monster.rarity * (state.isBoss ? config.bossCaptureMultiplier : 1) * 100;
    final hpRatio = state.monsterMaxHp == 0 ? 0.0 : (state.monsterHp / state.monsterMaxHp).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: regionColors(region?.id),
        ),
      ),
      child: Stack(
        children: [
          // 상단: 지역 · 진행
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: Row(
              children: [
                _Chip(text: region?.name ?? '???'),
                const Spacer(),
                if (state.isBoss)
                  _Chip(
                    text: '보스  ${state.bossTimeLeft.toStringAsFixed(1)}초',
                    color: Colors.red.shade700,
                  )
                else
                  _Chip(text: '${state.killsOnStage}/${config.killsPerStage}'),
              ],
            ),
          ),
          // 몬스터
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_bob, _hit, _spawn]),
              builder: (context, child) {
                final bobY = (_bob.value - 0.5) * 8;
                final hitT = _hit.value;
                final hitScale = 1 - 0.12 * (hitT < 0.5 ? hitT * 2 : (1 - hitT) * 2);
                final shakeX = hitT == 0 ? 0.0 : (hitT < 0.5 ? -6 : 6) * (1 - hitT);
                final spawnScale = Curves.easeOutBack.transform(_spawn.value.clamp(0.0, 1.0));
                return Transform.translate(
                  offset: Offset(shakeX, bobY),
                  child: Transform.scale(scale: hitScale * spawnScale, child: child),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MonsterSprite(monster: monster, size: state.isBoss ? 150 : 110, isBoss: state.isBoss),
                  const SizedBox(height: 8),
                  Text(
                    monster == null ? '몬스터' : '${monster.name}  [${monster.element.label}]',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          // 하단: HP · 도감/포획
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    if (monster != null)
                      Text(
                        state.starsOf(monster.id) > 0
                            ? '도감 ★${state.starsOf(monster.id)}'
                            : '미등록 · 포획 ${captureChance.toStringAsFixed(2)}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // 포획 연출
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
      ),
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
      decoration: BoxDecoration(
        color: color ?? Colors.black45,
        borderRadius: BorderRadius.circular(999),
      ),
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
