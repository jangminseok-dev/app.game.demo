import 'package:flutter/material.dart';

import '../../domain/balance_config.dart';
import '../../domain/dungeon.dart';
import '../../domain/game_state.dart';
import '../../domain/monster.dart';
import '../../domain/number_format.dart';
import 'pixel_ui.dart';

/// 좌상단 · 나에 관한 것. 전투력 · 골드 · 젬.
/// Lv·이름은 계정 시스템(3등급)이 생기면 붙는다.
class ProfileBadge extends StatelessWidget {
  const ProfileBadge({super.key, required this.state, required this.config});

  final GameState state;
  final BalanceConfig config;

  @override
  Widget build(BuildContext context) {
    final stats = state.statsWith(config);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PowerBadge(power: stats.dps(config)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CurrencyChip(amount: formatNumber(state.gold), color: PixelPalette.gold),
            const SizedBox(width: 5),
            const CurrencyChip(amount: '0', color: PixelPalette.gem, gem: true),
          ],
        ),
      ],
    );
  }
}

/// 상단 중앙 · 지금 상태. 층 이름 · 제한 시간 막대 · 남은 수.
/// 던전에 들어가 있으면 같은 자리에 던전 진행을 보여 준다.
class StageStatus extends StatelessWidget {
  const StageStatus({super.key, required this.state, required this.config, required this.regionName});

  final GameState state;
  final BalanceConfig config;
  final String regionName;

  @override
  Widget build(BuildContext context) {
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

    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelPanel(
            border: run == null ? PixelPalette.ink : PixelPalette.gem,
            child: PixelText(
              run == null ? '$regionName ${state.stage}층' : '${run.type.label} ${run.floor}층',
              size: 11,
              color: run == null ? PixelPalette.textDim : PixelPalette.gem,
            ),
          ),
          const SizedBox(height: 4),
          if (run == null && !state.isBoss)
            Row(
              children: [
                Expanded(
                  child: PixelGauge(
                    value: state.stageTimeRatio(config),
                    color: state.stageTimeRatio(config) > 0.25 ? PixelPalette.gold : PixelPalette.hpLow,
                    height: 7,
                  ),
                ),
                const SizedBox(width: 5),
                PixelText('${state.stageTimeLeftOr(config).ceil()}초', size: 10, color: PixelPalette.textDim),
              ],
            ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(child: PixelGauge(value: progress, color: accent, height: 10)),
              const SizedBox(width: 5),
              PixelPanel(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: run != null || state.isBoss ? accent : PixelPalette.panel,
                child: PixelText(_progressLabel(state, config, run), size: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 무대 하단 · 지금 무엇을 상대하는지와 포획 정보. 쓰러지면 그 안내.
class MonsterLine extends StatelessWidget {
  const MonsterLine({super.key, required this.state, required this.monster, required this.captureLine});

  final GameState state;
  final Monster? monster;
  final String captureLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelText(monster == null ? '몬스터' : '${monster!.name} [${monster!.element.label}]', size: 11),
            if (state.wave.length > 1) ...[
              const SizedBox(width: 6),
              PixelText('남은 ${state.wave.length}마리', size: 10, color: PixelPalette.gold),
            ],
            const SizedBox(width: 8),
            PixelText(captureLine, size: 10, color: PixelPalette.textDim),
          ],
        ),
        if (state.isDown) ...[
          const SizedBox(height: 3),
          PixelText('쓰러졌습니다 · ${state.reviveLeft.ceil()}초 뒤 일어섭니다', size: 11, color: PixelPalette.hpLow),
        ],
      ],
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
