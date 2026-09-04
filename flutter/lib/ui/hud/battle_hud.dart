import 'package:flutter/material.dart';

import '../../domain/balance_config.dart';
import '../../domain/dungeon.dart';
import '../../domain/game_state.dart';
import '../../domain/monster.dart';
import '../../domain/number_format.dart';
import 'pixel_ui.dart';

/// 전투 무대 위에 겹치는 HUD. 레퍼런스(가로)의 배치를 세로 화면에 옮긴 것.
///
/// 상단: 전투력 · 재화 · 지역 / 스테이지 진행 게이지
/// 하단: 몬스터 이름 · HP · 포획 정보
class BattleHud extends StatelessWidget {
  const BattleHud({
    super.key,
    required this.state,
    required this.config,
    required this.monster,
    required this.regionName,
    required this.captureLine,
  });

  final GameState state;
  final BalanceConfig config;
  final Monster? monster;
  final String regionName;
  final String captureLine;

  @override
  Widget build(BuildContext context) {
    final stats = state.statsWith(config);
    final hp = state.monsterMaxHp == 0 ? 0.0 : (state.monsterHp / state.monsterMaxHp).clamp(0.0, 1.0);
    // 던전에 들어가 있으면 같은 자리에 던전 진행을 보여 준다.
    final run = state.dungeon.run;
    final progress = run != null
        ? (1 - run.wavesLeft / config.dungeonWaves).clamp(0.0, 1.0)
        : state.isBoss
            ? 1.0
            : (state.killsOnStage / config.killsPerStage).clamp(0.0, 1.0);
    final accent = run != null
        ? PixelPalette.gem
        : state.isBoss
            ? PixelPalette.boss
            : PixelPalette.gold;

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 상단: 전투력 · 재화 · 지역
          Row(
            children: [
              _PowerBadge(power: stats.dps(config)),
              const SizedBox(width: 5),
              CurrencyChip(amount: formatNumber(state.gold), color: PixelPalette.gold),
              const SizedBox(width: 5),
              const CurrencyChip(amount: '0', color: PixelPalette.gem, gem: true),
              const Spacer(),
              PixelPanel(
                border: run == null ? PixelPalette.ink : PixelPalette.gem,
                child: PixelText(
                  run == null ? regionName : '${run.type.label} ${run.floor}층',
                  size: 11,
                  color: run == null ? PixelPalette.textDim : PixelPalette.gem,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // ── 스테이지 진행 게이지
          Row(
            children: [
              Expanded(
                child: PixelGauge(value: progress, color: accent, height: 12),
              ),
              const SizedBox(width: 5),
              PixelPanel(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: run != null || state.isBoss ? accent : PixelPalette.panel,
                child: PixelText(_progressLabel(state, config, run), size: 11),
              ),
            ],
          ),
          const Spacer(),
          // ── 주인공 체력·마력
          Row(
            children: [
              const PixelText('HP', size: 10, color: PixelPalette.textDim),
              const SizedBox(width: 4),
              Expanded(
                child: PixelGauge(
                  value: state.heroHpRatio(config),
                  color: state.heroHpRatio(config) > 0.3 ? PixelPalette.hp : PixelPalette.hpLow,
                  height: 9,
                ),
              ),
              const SizedBox(width: 6),
              const PixelText('MP', size: 10, color: PixelPalette.textDim),
              const SizedBox(width: 4),
              Expanded(
                child: PixelGauge(value: state.heroMpRatio(config), color: PixelPalette.gem, height: 9),
              ),
            ],
          ),
          const SizedBox(height: 2),
          PixelText(
            state.isDown
                ? '쓰러졌습니다 · ${state.reviveLeft.ceil()}초 뒤 일어섭니다'
                : '${formatNumber(state.heroHpOr(config))} / ${formatNumber(state.maxHeroHp(config))}'
                    ' · 마력 ${formatNumber(state.heroMpOr(config))}',
            size: 10,
            color: state.isDown ? PixelPalette.hpLow : PixelPalette.textDim,
          ),
          const SizedBox(height: 4),
          // ── 하단: 몬스터 정보
          Row(
            children: [
              PixelText(
                monster == null ? '몬스터' : '${monster!.name} [${monster!.element.label}]',
                size: 12,
              ),
              if (state.wave.length > 1) ...[
                const SizedBox(width: 6),
                PixelText('남은 ${state.wave.length}마리', size: 11, color: PixelPalette.gold),
              ],
              const Spacer(),
              Flexible(child: PixelText(captureLine, size: 10, color: PixelPalette.textDim)),
            ],
          ),
          const SizedBox(height: 3),
          PixelGauge(value: hp, color: hp > 0.3 ? PixelPalette.hp : PixelPalette.hpLow, height: 11),
          const SizedBox(height: 2),
          PixelText(
            'HP ${formatNumber(state.monsterHp)} / ${formatNumber(state.monsterMaxHp)}',
            size: 10,
            color: PixelPalette.textDim,
          ),
        ],
      ),
    );
  }
}

/// 좌상단 전투력 뱃지 — 레퍼런스의 레벨 문장 자리.
class _PowerBadge extends StatelessWidget {
  const _PowerBadge({required this.power});

  final double power;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
      color: PixelPalette.panelLight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 12, height: 12, child: CustomPaint(painter: _SwordIcon())),
          const SizedBox(width: 5),
          PixelText(formatNumber(power), size: 11, color: PixelPalette.gold),
        ],
      ),
    );
  }
}

class _SwordIcon extends CustomPainter {
  const _SwordIcon();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..isAntiAlias = false
      ..color = PixelPalette.gold;
    final w = size.width;
    // 아주 단순한 검 실루엣 — 날 + 가드 + 손잡이
    canvas.drawRect(Rect.fromLTWH(w * 0.42, 0, w * 0.16, w * 0.62), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.2, w * 0.62, w * 0.6, w * 0.12), p..color = PixelPalette.goldDark);
    canvas.drawRect(Rect.fromLTWH(w * 0.42, w * 0.74, w * 0.16, w * 0.26), p);
  }

  @override
  bool shouldRepaint(_SwordIcon old) => false;
}

/// 진행 게이지 옆 숫자. 던전 · 보스 · 일반 순으로 다르게 읽힌다.
String _progressLabel(GameState state, BalanceConfig config, DungeonRun? run) {
  if (run != null) return '남은 ${run.wavesLeft} · ${run.timeLeft.toStringAsFixed(0)}초';
  if (state.isBoss) return '보스 ${state.bossTimeLeft.toStringAsFixed(1)}';
  return '${state.killsOnStage}/${config.killsPerStage}';
}
