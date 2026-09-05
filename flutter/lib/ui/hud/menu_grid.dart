import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../domain/attendance.dart';
import '../../domain/daily.dart';
import '../attendance_panel.dart';
import '../codex_screen.dart';
import '../contents_panel.dart';
import '../daily_panel.dart';
import 'game_popup.dart';
import 'pixel_icons.dart';
import 'pixel_ui.dart';

/// 우상단 ≡ 가 여는 메뉴 그리드. 진입점 전부가 여기 한 장에 있다.
///
/// 레퍼런스는 20칸을 접지 않고 4열로 펼친다. 새 화면이 늘면 칸을 하나 더 붙인다.
/// 첫 줄은 우상단에 이미 있는 셋(콘텐츠·소환·상점)이라 같은 것을 여기서도 연다.
Future<void> showMenuGrid(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _MenuGrid(),
  );
}

class _MenuGrid extends ConsumerWidget {
  const _MenuGrid();

  void _soon(BuildContext context, String what) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: PixelText('$what — 준비 중', size: 12), duration: const Duration(seconds: 1)),
    );
  }

  void _open(BuildContext context, String title, Widget child, {double heightFactor = 0.72}) {
    Navigator.of(context).pop();
    showGamePopup(context, title: title, heightFactor: heightFactor, child: child);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final registered = state.codex.values.where((s) => s > 0).length;

    // 4열. 순서는 스펙 3절 그대로. 마지막 줄은 둘만 있다.
    final cells = <Widget>[
      HudButton(label: '콘텐츠', icon: PixelIcon.gate, badge: '${state.dungeon.tickets}',
          onTap: () => _open(context, '콘텐츠', const ContentsPanel())),
      HudButton(label: '소환', icon: PixelIcon.spark, locked: true, onTap: () => _soon(context, '소환')),
      HudButton(label: '상점', icon: PixelIcon.shop, locked: true, onTap: () => _soon(context, '상점')),
      HudButton(label: '닫기', icon: PixelIcon.menu, onTap: () => Navigator.of(context).pop()),

      HudButton(label: '캐릭터', icon: PixelIcon.flag, locked: true, onTap: () => _soon(context, '캐릭터')),
      HudButton(label: '강화', icon: PixelIcon.hammer, locked: true, onTap: () => _soon(context, '강화')),
      HudButton(label: '영지', icon: PixelIcon.gate, locked: true, onTap: () => _soon(context, '영지')),
      HudButton(label: '동료', icon: PixelIcon.egg, locked: true, onTap: () => _soon(context, '동료')),

      HudButton(label: '출석', icon: PixelIcon.check, alert: state.attendance.canClaim(epochDayOf(DateTime.now())),
          onTap: () => _open(context, '출석부', const AttendancePanel(), heightFactor: 0.55)),
      HudButton(label: '오늘', icon: PixelIcon.calendar, alert: anyDailyReady(state),
          onTap: () => _open(context, '오늘 과제', const DailyPanel(), heightFactor: 0.5)),
      HudButton(label: '랭킹', icon: PixelIcon.flag, locked: true, onTap: () => _soon(context, '랭킹')),
      HudButton(label: '도감 $registered', icon: PixelIcon.book, onTap: () => _open(context, '도감', const CodexTab())),

      HudButton(label: '도움말', icon: PixelIcon.book, locked: true, onTap: () => _soon(context, '도움말')),
      HudButton(label: '설정', icon: PixelIcon.pin, locked: true, onTap: () => _soon(context, '설정')),
    ];

    return Center(
      child: PixelPanel(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 320,
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.9,
            children: cells,
          ),
        ),
      ),
    );
  }
}
