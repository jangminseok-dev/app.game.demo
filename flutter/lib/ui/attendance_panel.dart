import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/attendance.dart';
import '../domain/number_format.dart';
import 'hud/pixel_icons.dart';
import 'hud/pixel_ui.dart';
import 'hud/reward_popup.dart';

/// 출석부 — 하루에 한 번, 7일 표를 돌린다.
///
/// 접속 이유를 하루 단위로 하나 만든다. 표는 짧게 두고 반복시키는 쪽이 관리가 쉽다.
class AttendancePanel extends ConsumerWidget {
  const AttendancePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final attendance = state.attendance;
    final today = epochDayOf(DateTime.now());
    final canClaim = attendance.canClaim(today);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PixelPanel(
          padding: const EdgeInsets.all(12),
          border: canClaim ? PixelPalette.gold : PixelPalette.ink,
          child: Row(
            children: [
              PixelText('${attendance.claimedDays}일째', size: 16, color: PixelPalette.gold),
              const Spacer(),
              GestureDetector(
                onTap: canClaim
                    ? () {
                        final got = controller.claimAttendance();
                        if (got == null) return;
                        showRewardPopup(context, title: '출석 보상', icon: PixelIcon.calendar, lines: [
                          '${got.$1.label} +${formatNumber(got.$2.toDouble())}',
                        ]);
                      }
                    : null,
                child: PixelPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: canClaim ? PixelPalette.goldDark : const Color(0xFF3A3342),
                  child: PixelText(
                    canClaim ? '받기' : '내일 다시',
                    size: 13,
                    color: canClaim ? PixelPalette.text : PixelPalette.textDim,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.95,
          children: [
            for (var i = 0; i < attendanceTable.length; i++)
              _DayTile(
                day: i + 1,
                kind: attendanceTable[i].$1.label,
                amount: attendanceTable[i].$2,
                today: i == attendance.todaySlot,
                done: i < attendance.todaySlot,
              ),
          ],
        ),
        const SizedBox(height: 10),
        const PixelText('7일을 다 받으면 처음으로 돌아옵니다', size: 10, color: PixelPalette.textDim),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.kind,
    required this.amount,
    required this.today,
    required this.done,
  });

  final int day;
  final String kind;
  final int amount;
  final bool today;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.all(5),
      color: done ? const Color(0xFF241E2B) : PixelPalette.panel,
      border: today ? PixelPalette.gold : PixelPalette.ink,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PixelText('DAY $day', size: 10, color: today ? PixelPalette.gold : PixelPalette.textDim),
          const SizedBox(height: 4),
          PixelText(kind, size: 9, color: PixelPalette.textDim),
          PixelText(formatNumber(amount.toDouble()), size: 10),
        ],
      ),
    );
  }
}
