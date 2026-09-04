import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import 'hud/pixel_ui.dart';

/// 층 이동 화면 — 최고 층 이하 아무 데나 갈 수 있다.
///
/// 벽에 막히면 한 층만 반복하게 된다. 내려가서 사냥할 길이 있어야
/// "막혔다"가 "할 일이 없다"로 이어지지 않는다(기획서 6장).
class StageSelectPanel extends ConsumerWidget {
  const StageSelectPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final catalog = ref.watch(monsterCatalogProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final highest = state.highestStage;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PixelPanel(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PixelText('현재 ${state.stage}층', size: 16, color: PixelPalette.gold),
              const SizedBox(width: 12),
              PixelText('최고 $highest층', size: 11, color: PixelPalette.textDim),
              const Spacer(),
              _Button(
                label: '최고 층으로',
                enabled: state.stage != highest,
                onTap: () => controller.travelTo(highest),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── 한 칸씩 움직이기
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final step in [-10, -1, 1, 10])
              _Button(
                label: step > 0 ? '+$step' : '$step',
                enabled: (state.stage + step).clamp(1, highest) != state.stage,
                onTap: () => controller.travelTo(state.stage + step),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const PixelText('지역', size: 13),
        const SizedBox(height: 6),
        if (catalog.regions.isEmpty)
          const PixelText('지역 정보를 불러오지 못했습니다', size: 11, color: PixelPalette.textDim)
        else
          for (final region in catalog.regions) ...[
            _RegionRow(
              name: region.name,
              from: region.stageFrom,
              to: region.stageTo,
              highest: highest,
              here: region.contains(state.stage),
              onTap: () => controller.travelTo(region.stageFrom),
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }
}

/// 지역 한 줄. 아직 못 간 지역은 여는 층을 그대로 보여 준다.
class _RegionRow extends StatelessWidget {
  const _RegionRow({
    required this.name,
    required this.from,
    required this.to,
    required this.highest,
    required this.here,
    required this.onTap,
  });

  final String name;
  final int from;
  final int? to;
  final int highest;
  final bool here;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = highest >= from;
    final range = to == null ? '$from층~' : '$from~$to층';
    return PixelPanel(
      padding: const EdgeInsets.all(10),
      color: open ? PixelPalette.panel : const Color(0xFF241E2B),
      border: here ? PixelPalette.gold : PixelPalette.ink,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(name, size: 12, color: open ? PixelPalette.text : PixelPalette.textDim),
                const SizedBox(height: 3),
                PixelText(
                  open ? range : '$from층에 도달하면 열립니다',
                  size: 10,
                  color: PixelPalette.textDim,
                ),
              ],
            ),
          ),
          if (here)
            const PixelText('여기', size: 11, color: PixelPalette.gold)
          else
            _Button(label: '이동', enabled: open, onTap: onTap),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        color: enabled ? PixelPalette.goldDark : const Color(0xFF3A3342),
        child: PixelText(label, size: 11, color: enabled ? PixelPalette.text : PixelPalette.textDim),
      ),
    );
  }
}
