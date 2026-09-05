import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/summon.dart';
import 'hud/game_popup.dart';
import 'hud/pixel_icons.dart';
import 'hud/pixel_ui.dart';
import 'hud/popup_two_pane.dart';
import 'hud/reward_popup.dart';

/// 소환 — 유물 네 칸을 굴려 주인공을 용으로 키운다. 유물 / 정령 2탭.
///
/// 정령은 이번 계획 밖이라 탭 자리만 두고 잠근다(스펙 6절).
class SummonPanel extends ConsumerStatefulWidget {
  const SummonPanel({super.key});

  @override
  ConsumerState<SummonPanel> createState() => _SummonPanelState();
}

class _SummonPanelState extends ConsumerState<SummonPanel> {
  int _tab = 0;
  List<SummonResult> _results = const [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _Tab(label: '유물', on: _tab == 0, onTap: () => setState(() => _tab = 0)),
            const SizedBox(width: 4),
            _Tab(label: '정령', on: _tab == 1, onTap: () => setState(() => _tab = 1)),
            const Spacer(),
            if (_tab == 0)
              GestureDetector(
                onTap: () => _showRateTable(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PixelText('확률 보기', size: 11, color: PixelPalette.textDim),
                    PixelText(' ▸', size: 11, color: PixelPalette.textDim),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _tab == 0
              ? _RelicTab(results: _results, onSummon: _summon)
              : const Center(child: PixelText('정령 — 준비 중', size: 12, color: PixelPalette.textDim)),
        ),
      ],
    );
  }

  void _summon(int count) {
    final controller = ref.read(gameControllerProvider.notifier);
    final results = controller.summonRelic(count: count);
    if (results.isEmpty) return;
    setState(() => _results = results);
    showRewardPopup(
      context,
      title: '소환',
      icon: PixelIcon.spark,
      lines: [for (final r in results) '${r.slot.label} ★${r.stars}'],
    );
  }

  /// `확률 보기` — relicStarChances를 그대로 읽어 그린다. 손으로 다시 적으면 코드와 갈라진다.
  void _showRateTable(BuildContext context) {
    showGamePopup(
      context,
      title: '확률',
      icon: PixelIcon.spark,
      heightFactor: 0.5,
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          for (final entry in relicStarChances.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  PixelText('★${entry.key}', size: 12, color: PixelPalette.gold),
                  const Spacer(),
                  PixelText('${(entry.value * 100).round()}%', size: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 유물 탭 본문 — 왼쪽 지금 낀 것, 오른쪽 나온 것.
class _RelicTab extends ConsumerWidget {
  const _RelicTab({required this.results, required this.onSummon});

  final List<SummonResult> results;
  final void Function(int count) onSummon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final summon = state.summon;
    final config = ref.watch(balanceConfigProvider);
    final stage = summon.dragonStage;
    final remainToNext =
        stage >= SummonState.maxStars ? null : (stage + 1) * RelicSlot.values.length - summon.totalStars;

    return PopupTwoPane(
      // ── 왼쪽: 지금 낀 것. 중복이 자동 승급이라 고를 것이 없어 action이 없다.
      left: PopupPane(
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            for (final slot in RelicSlot.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    PixelText(slot.label, size: 12),
                    const Spacer(),
                    PixelText('★${summon.starsOf(slot)}', size: 12, color: PixelPalette.gold),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            PixelText('용화 $stage단계', size: 13, color: PixelPalette.gold),
            const SizedBox(height: 2),
            PixelText(
              remainToNext == null ? '다음 단계 없음' : '다음 단계까지 성급 $remainToNext',
              size: 10,
              color: PixelPalette.textDim,
            ),
          ],
        ),
      ),
      // ── 오른쪽: 나온 것, 천장 카운터, 소환석, 소환 단추.
      right: PopupPane(
        action: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Button(label: '1회', enabled: summon.canSummon(config), onTap: () => onSummon(1)),
            const SizedBox(width: 6),
            _Button(label: '10회', enabled: summon.canSummonTen(config), onTap: () => onSummon(10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: results.isEmpty
                  ? const Center(child: PixelText('아직 없음', size: 11, color: PixelPalette.textDim))
                  : ListView(
                      padding: const EdgeInsets.all(4),
                      children: [
                        for (final r in results)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: PixelText('[${r.slot.label} ★${r.stars}]', size: 11),
                          ),
                      ],
                    ),
            ),
            PixelText('★5까지 ${config.summonPity - summon.pityCount}회', size: 10, color: PixelPalette.textDim),
            const SizedBox(height: 2),
            PixelText('소환석 ${summon.stones}', size: 11, color: PixelPalette.textDim),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: PixelPanel(
        color: on ? PixelPalette.goldDark : PixelPalette.panelDark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: PixelText(label, size: 12, color: on ? PixelPalette.text : PixelPalette.textDim),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: PixelPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: enabled ? PixelPalette.goldDark : const Color(0xFF3A3342),
        child: PixelText(label, size: 11, color: enabled ? PixelPalette.text : PixelPalette.textDim),
      ),
    );
  }
}
