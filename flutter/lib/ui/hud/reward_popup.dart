import 'package:flutter/material.dart';

import 'pixel_ui.dart';

/// 무엇을 얻었는지 알리는 연출 하나. 퀘스트·던전·제작·해금이 전부 이것을 쓴다.
///
/// 시스템마다 다른 연출을 만들면 새 시스템을 붙일 때마다 플레이어가 새로 배워야 한다.
/// 레퍼런스도 "보상 → 결과 → 빈 곳을 터치하세요" 한 가지만 쓴다.
Future<void> showRewardPopup(
  BuildContext context, {
  String title = '보상',
  required List<String> lines,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    builder: (context) => _RewardOverlay(title: title, lines: lines),
  );
}

class _RewardOverlay extends StatelessWidget {
  const _RewardOverlay({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 제목 띠
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PixelPalette.gem.withValues(alpha: 0),
                    PixelPalette.gem.withValues(alpha: 0.55),
                    PixelPalette.gem.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Center(child: PixelText(title, size: 18, color: PixelPalette.text)),
            ),
            const SizedBox(height: 26),
            const PixelText('결과', size: 12, color: PixelPalette.textDim),
            const SizedBox(height: 10),
            for (final line in lines) ...[
              PixelPanel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: PixelPalette.gold,
                child: PixelText(line, size: 13, color: PixelPalette.gold),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 26),
            const PixelText('빈 곳을 터치하세요', size: 11, color: PixelPalette.textDim),
          ],
        ),
      ),
    );
  }
}

/// 보스가 나올 때 잠깐 지나가는 경고 띠.
class BossWarningBanner extends StatelessWidget {
  const BossWarningBanner({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        // 앞뒤로 짧게 뜨고 사라진다.
        final opacity = t < 0.12 ? t / 0.12 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
        return IgnorePointer(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PixelPalette.boss.withValues(alpha: 0),
                      PixelPalette.boss.withValues(alpha: 0.7),
                      PixelPalette.boss.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: const Center(child: PixelText('WARNING  BOSS', size: 20)),
              ),
            ),
          ),
        );
      },
    );
  }
}
