import 'dart:math';

/// 전투가 벌어지는 판의 크기와 자리. 화면의 가상 해상도와 같은 단위를 쓴다.
///
/// 좌표를 도메인에 두는 이유는 "가까운 몬스터에게 간다", "몬스터가 한꺼번에 달려든다" 같은
/// 규칙이 연출이 아니라 전투 규칙이기 때문이다. 무대는 이 좌표를 그대로 그린다.
const fieldWidth = 360.0;
const fieldHeight = 270.0;

/// 주인공이 아무도 없을 때 서 있는 자리.
const heroHomeX = 58.0;
const heroHomeY = 204.0;

/// 몬스터가 걸어 들어오기 시작하는 x. 화면 밖이다.
const monsterSpawnX = 400.0;

/// 몬스터가 설 수 있는 세로 범위. 3/4 시점이라 위아래로 퍼져야 깊이가 보인다.
const fieldTopY = 158.0;
const fieldBottomY = 238.0;

/// 서로 겹치지 않게 밀어내는 거리.
const separationRadius = 20.0;

/// 두 점 사이 거리.
double distanceBetween(double ax, double ay, double bx, double by) {
  final dx = ax - bx;
  final dy = ay - by;
  return sqrt(dx * dx + dy * dy);
}

/// [from]에서 [to] 쪽으로 [step]만큼 간 좌표. 남은 거리보다 크면 목표에 딱 멈춘다.
(double, double) moveToward(
  double fromX,
  double fromY,
  double toX,
  double toY,
  double step,
) {
  final dx = toX - fromX;
  final dy = toY - fromY;
  final length = sqrt(dx * dx + dy * dy);
  if (length <= step || length == 0) return (toX, toY);
  return (fromX + dx / length * step, fromY + dy / length * step);
}

/// 판 안으로 좌표를 밀어 넣는다.
(double, double) clampToField(double x, double y) =>
    (x.clamp(-80.0, monsterSpawnX + 40), y.clamp(fieldTopY, fieldBottomY));
