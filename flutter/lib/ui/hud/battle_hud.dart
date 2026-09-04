import 'package:flutter/material.dart';

import '../../domain/balance_config.dart';
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
    final progress = state.isBoss ? 1.0 : (state.killsOnStage / config.killsPerStage).clamp(0.0, 1.0);

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
              PixelPanel(child: PixelText(regionName, size: 11, color: PixelPalette.textDim)),
            ],
          ),
          const SizedBox(height: 5),
          // ── 스테이지 진행 게이지
          Row(
            children: [
              Expanded(
                child: PixelGauge(
                  value: progress,
                  color: state.isBoss ? PixelPalette.boss : PixelPalette.gold,
                  height: 12,
                ),
              ),
              const SizedBox(width: 5),
              PixelPanel(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: state.isBoss ? PixelPalette.boss : PixelPalette.panel,
                child: PixelText(
                  state.isBoss ? '보스 ${state.bossTimeLeft.toStringAsFixed(1)}' : '${state.killsOnStage}/${config.killsPerStage}',
                  size: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          // ── 하단: 몬스터 정보
          Row(
            children: [
              PixelText(
                monster == null ? '몬스터' : '${monster!.name} [${monster!.element.label}]',
                size: 12,
              ),
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
