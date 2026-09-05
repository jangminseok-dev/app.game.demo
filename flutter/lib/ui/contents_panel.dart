import 'package:flutter/material.dart';

import 'dungeon_panel.dart';
import 'hud/pixel_ui.dart';
import 'stage_select_panel.dart';

/// 콘텐츠 — 전투 밖으로 나가는 곳. 던전 / 도전 2탭.
///
/// 레퍼런스도 콘텐츠 안에 던전·도전을 둔다. 층 이동은 성격이 "바깥으로"라 던전 탭에 같이 둔다.
/// 도전(아레나)은 3등급이라 지금은 비어 있다.
class ContentsPanel extends StatefulWidget {
  const ContentsPanel({super.key});

  @override
  State<ContentsPanel> createState() => _ContentsPanelState();
}

class _ContentsPanelState extends State<ContentsPanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _Tab(label: '던전', on: _tab == 0, onTap: () => setState(() => _tab = 0)),
            const SizedBox(width: 4),
            _Tab(label: '도전', on: _tab == 1, onTap: () => setState(() => _tab = 1)),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _tab == 0
              ? ListView(
                  children: const [
                    PixelText('층 이동', size: 11, color: PixelPalette.textDim),
                    SizedBox(height: 4),
                    // 두 패널이 각각 ListView라 안쪽은 스크롤을 끄고 바깥이 한 번에 민다.
                    _Unscrolled(child: StageSelectPanel()),
                    SizedBox(height: 10),
                    PixelText('던전', size: 11, color: PixelPalette.textDim),
                    SizedBox(height: 4),
                    _Unscrolled(child: DungeonPanel()),
                  ],
                )
              : const Center(child: PixelText('아레나 — 준비 중', size: 12, color: PixelPalette.textDim)),
        ),
      ],
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: PixelPanel(
          color: on ? PixelPalette.goldDark : PixelPalette.panelDark,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(child: PixelText(label, size: 12, color: on ? PixelPalette.text : PixelPalette.textDim)),
        ),
      ),
    );
  }
}

/// ListView 안에 ListView를 넣을 때 안쪽 스크롤을 끈다.
class _Unscrolled extends StatelessWidget {
  const _Unscrolled({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: child,
      );
}
