import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/attendance.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);
  final initial = GameState.initial(config);

  test('하루에 한 번만 받는다', () {
    final first = engine.claimAttendance(initial, 100)!.\$1;
    expect(first.attendance.claimedDays, 1);
    expect(engine.claimAttendance(first, 100), isNull, reason: '같은 날 두 번은 안 된다');
    expect(engine.claimAttendance(first, 101), isNotNull, reason: '다음 날은 된다');
  });

  test('7일을 다 받으면 처음으로 돌아온다', () {
    var s = initial;
    for (var day = 0; day < attendanceTable.length; day++) {
      s = engine.claimAttendance(s, 200 + day)!.$1;
    }
    expect(s.attendance.claimedDays, attendanceTable.length);
    expect(s.attendance.todaySlot, 0, reason: '한 바퀴 돌았다');
  });

  test('건너뛴 날은 그냥 넘어간다 — 연속이 아니어도 된다', () {
    var s = engine.claimAttendance(initial, 10)!.$1;
    s = engine.claimAttendance(s, 30)!.$1;
    expect(s.attendance.claimedDays, 2, reason: '20일을 건너뛰어도 다음 칸을 받는다');
  });

  test('받으면 재화가 실제로 들어온다', () {
    final (next, kind, amount) = engine.claimAttendance(initial, 1)!;
    expect(amount, greaterThan(0));
    expect(kind, attendanceTable.first.$1);
    expect(next.gold, greaterThan(initial.gold), reason: '첫날은 골드');
  });

  test('표는 비어 있지 않고 보상도 0이 아니다', () {
    expect(attendanceTable, isNotEmpty);
    for (final row in attendanceTable) {
      expect(row.$2, greaterThan(0));
    }
  });

  test('날짜 계산은 같은 날이면 같은 값이다', () {
    expect(epochDayOf(DateTime(2026, 9, 4, 1)), epochDayOf(DateTime(2026, 9, 4, 23)));
    expect(epochDayOf(DateTime(2026, 9, 5)), epochDayOf(DateTime(2026, 9, 4)) + 1);
  });

  test('출석 기록은 저장된다', () {
    final s = engine.claimAttendance(initial, 55)!.$1;
    final back = decodeState(encodeState(s))!;
    expect(back.attendance.claimedDays, 1);
    expect(back.attendance.lastClaimDay, 55);
  });

  test('출석부 이전 저장도 읽힌다', () {
    final j = encodeState(initial)..remove('attendance');
    expect(decodeState(j)!.attendance.claimedDays, 0);
  });
}
