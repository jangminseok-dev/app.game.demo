import 'quest.dart';

/// 출석부 7일 표. 하루에 한 번 받고 7일이 지나면 처음으로 돌아온다.
///
/// 접속 이유를 하루 단위로 하나 만든다. 방치형은 "오늘 열어야 할 이유"가 없으면
/// 이탈이 조용히 일어난다. 표는 짧게 두고 반복시키는 쪽이 관리가 쉽다.
const attendanceTable = <(RewardKind, int)>[
  (RewardKind.gold, 3000),
  (RewardKind.stone, 40),
  (RewardKind.ticket, 1),
  (RewardKind.eggShard, 60),
  (RewardKind.summonStone, 90),
  (RewardKind.skillPage, 50),
  (RewardKind.ticket, 2),
];

/// 며칠째 받았는지와 마지막으로 받은 날.
///
/// 날짜는 도메인 밖에서 넣어 준다. 순수하게 두어야 테스트에서 날을 마음대로 넘길 수 있다.
class AttendanceState {
  const AttendanceState({this.claimedDays = 0, this.lastClaimDay = -1});

  static const empty = AttendanceState();

  /// 지금까지 받은 날 수. 7로 나눈 나머지가 오늘 받을 칸이다.
  final int claimedDays;

  /// 마지막으로 받은 날(에포크 기준 일수). -1이면 받은 적이 없다.
  final int lastClaimDay;

  /// 오늘 받을 칸(0부터). 표를 한 바퀴 돌면 다시 0으로 온다.
  int get todaySlot => claimedDays % attendanceTable.length;

  bool canClaim(int today) => lastClaimDay != today;

  /// 오늘 것을 받는다. 이미 받았으면 그대로 돌려준다.
  AttendanceState claim(int today) => canClaim(today)
      ? AttendanceState(claimedDays: claimedDays + 1, lastClaimDay: today)
      : this;

  Map<String, dynamic> toJson() => {'claimedDays': claimedDays, 'lastClaimDay': lastClaimDay};

  factory AttendanceState.fromJson(Map<String, dynamic> j) => AttendanceState(
        claimedDays: (j['claimedDays'] as num? ?? 0).toInt(),
        lastClaimDay: (j['lastClaimDay'] as num? ?? -1).toInt(),
      );
}

/// 날짜를 에포크 기준 일수로. 기기 시각의 자정을 기준으로 삼는다.
///
/// 시간대를 넘나들면 하루가 어긋날 수 있지만 출석 보상은 그 정도 오차가 문제되지 않는다.
/// 엄밀함이 필요해지면 서버 시각으로 옮긴다.
int epochDayOf(DateTime at) => DateTime(at.year, at.month, at.day).millisecondsSinceEpoch ~/ 86400000;
