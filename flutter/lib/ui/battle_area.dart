import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/codex.dart';
import '../domain/game_state.dart';
import '../domain/number_format.dart';
import '../domain/upgrade.dart';
import 'sprites/monster_sprite.dart';

/// 전투 무대 — 지역 배경, 몬스터(둥실·피격·등장), 데미지 숫자, 보스 등장 흔들림, HP 바, 포획 연출.
///
/// 게임 상태를 바꾸지 않는다. 상태 변화를 보고 연출만 트리거한다.
class BattleArea extends ConsumerStatefulWidget {
  const BattleArea({super.key});

  @override
  ConsumerState<BattleArea> createState() => _BattleAreaState();
}

/// 떠오르는 데미지 숫자 1개.
class _Floater {
  _Floater({required this.text, required this.color, required this.big, required this.born, required this.dx});
  final String text;
  final Color color;
  final bool big;
  final Duration born;
  final double dx;
}

class _BattleAreaState extends ConsumerState<BattleArea> with TickerProviderStateMixin {
  static const _floaterLife = Duration(milliseconds: 750);

  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  late final AnimationController _hit = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
  late final AnimationController _spawn =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _capture = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final Ticker _ticker = createTicker(_onTick);
  Duration _clock = Duration.zero;
  final _floaters = <_Floater>[];
  final _rng = math.Random();
  String _captureText = '';

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _bob.dispose();
    _hit.dispose();
    _spawn.dispose();
    _shake.dispose();
    _capture.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _clock = elapsed;
    if (_floaters.isEmpty) return;
    final before = _floaters.length;
    _floaters.removeWhere((f) => elapsed - f.born > _floaterLife);
    if (before != _floaters.length || _floaters.isNotEmpty) setState(() {});
  }

  void _onStateChange(GameState prev, GameState next) {
    final spawned = next.totalKills > prev.totalKills || next.monsterId != prev.monsterId || next.isBoss != prev.isBoss;
    final damage = prev.monsterHp - next.monsterHp;
    if (damage > 0 || spawned) {
      // 처치로 새 몬스터가 나왔으면 마지막 타격은 이전 몬스터의 남은 HP만큼이다.
      final dealt = spawned && next.totalKills > prev.totalKills ? prev.monsterHp : damage;
      if (dealt > 0) _addFloater(dealt, prev.statsWith(ref.read(balanceConfigProvider)).attack);
    }
    if (spawned) {
      _spawn.forward(from: 0);
      if (next.isBoss && !prev.isBoss) _shake.forward(from: 0);
    } else if (damage > 0) {
      _hit.forward(from: 0);
    }
  }

  void _addFloater(double dealt, double baseAttack) {
    // 치명타 판정은 도메인이 노출하지 않는다 — 기본 공격보다 확실히 크면 치명타로 본다(연출 전용 추정).
    final crit = dealt > baseAttack * 1.5;
    _floaters.add(_Floater(
      text: formatNumber(dealt),
      color: crit ? Colors.amber : Colors.white,
      big: crit,
      born: _clock,
      dx: (_rng.nextDouble() - 0.5) * 60,
    ));
    if (_floaters.length > 8) _floaters.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider, (prev, next) {
      if (prev != null) _onStateChange(prev, next);
    });
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

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final amp = t == 0 || t == 1 ? 0.0 : (1 - t) * 10;
        return Transform.translate(
          offset: Offset(math.sin(t * math.pi * 8) * amp, math.cos(t * math.pi * 6) * amp * 0.5),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: regionColors(region?.id),
          ),
        ),
        child: Stack(
          children: [
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
            // 데미지 숫자
            for (final f in _floaters)
              Builder(builder: (context) {
                final t = ((_clock - f.born).inMilliseconds / _floaterLife.inMilliseconds).clamp(0.0, 1.0);
                return Align(
                  alignment: Alignment(f.dx / 120, -0.1 - t * 0.5),
                  child: Opacity(
                    opacity: t < 0.7 ? 1 : (1 - t) / 0.3,
                    child: Text(
                      f.text,
                      style: TextStyle(
                        color: f.color,
                        fontSize: f.big ? 26 : 16,
                        fontWeight: FontWeight.w800,
                        shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
                      ),
                    ),
                  ),
                );
              }),
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
        ),
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
