import 'dart:math';

/// 전투가 벌어지는 판의 자리. 화면의 가상 해상도와 같은 단위를 쓴다.
///
/// 좌표를 도메인에 두는 이유는 "가까운 몬스터에게 간다", "몬스터가 한꺼번에 달려든다" 같은
/// 규칙이 연출이 아니라 전투 규칙이기 때문이다. 무대는 이 좌표를 그대로 그린다.
///
/// **가로는 끝이 없다**(스펙 4.3). 주인공이 몬스터를 맞이하러 오른쪽으로 나아가고 되돌아오지 않는다.
/// 몬스터는 주인공 기준으로 나타난다. 가로를 자르는 상수를 새로 만들면 안 된다 —
/// 2026-09-05까지 무대 폭이 360으로 막혀 있어서 세로로 긴 창에서 캐릭터가 화면 밖으로 나갔다.

/// 무대 세로. 가로와 달리 끝이 있다.
const fieldHeight = 480.0;

/// 주인공이 서는 높이. 걷는 띠의 가운데다.
const heroHomeY = 355.0;

/// 몬스터가 나타나는 자리 — 주인공에서 오른쪽으로 이만큼.
///
/// 불감대가 ±80이라 카메라 중심이 주인공에서 최대 80 벌어지고, 보이는 가로의 절반이 320이다.
/// 오른쪽 끝이 가장 멀리 가는 경우가 주인공+400이므로 그 바깥 20에 세운다.
/// 안쪽에 세우면 걸어 들어오는 것이 화면 안에서 튀어나온다.
const spawnAheadOfHero = 420.0;

/// 몬스터가 설 수 있는 세로 범위. 3/4 시점이라 위아래로 퍼져야 깊이가 보인다.
/// 위는 지평선(250) 아래로 50 — 머리가 지평선에 걸쳐야 3/4 시점이 자연스럽다.
/// 아래는 410에서 끊는다. 하단 HUD가 논리 69이고 가장 낮은 배율 1.32에서 세계 52를 가린다.
const fieldTopY = 300.0;
const fieldBottomY = 410.0;

/// 서로 겹치지 않게 밀어내는 거리. 몸이 24픽셀이니 0.83몸이다.
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

/// 걷는 띠 안으로 높이를 밀어 넣는다. 가로는 끝이 없어 자르지 않는다.
double clampToBand(double y) => y.clamp(fieldTopY, fieldBottomY);
