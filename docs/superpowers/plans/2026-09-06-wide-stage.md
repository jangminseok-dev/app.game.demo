# 넓은 무대와 따라가는 카메라 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 창 모양과 무관하게 캐릭터가 화면 가로의 4.4%로 고정되고, 맵이 가로로 끝없이 이어지며 카메라가 주인공을 불감대로 따라간다.

**Architecture:** 도메인 좌표에서 가로 경계를 없애고 세로를 480으로 넓힌다(태스크 1). 무대 카메라를 640×480 상자를 덮는 고정 배율 + 불감대 추적으로 바꾸고 스프라이트를 정확히 절반으로 그린다(태스크 2). 배경을 두 겹 시차로 가로 되풀이한다(태스크 3).

**Tech Stack:** Flutter 3.44.8 · Flame(FlameGame·CameraComponent) · 순수 Dart 도메인

**Spec:** `docs/superpowers/specs/2026-09-06-wide-stage-design.md`

**범위:** 스펙 9절의 1~3단계다. **아트 발주(4·5단계)는 이 계획에 없다** — 지금 스프라이트를 절반 크기로 그려 쓰고, 앱으로 크기를 확인한 뒤 별도 계획으로 발주한다. 크기가 틀렸을 때 돈이 날아가지 않게 하려는 순서다.

## Global Constraints

- **보이는 상자는 640×480이다.** 배율은 `max(vp.x / 640, vp.y / 480)`이고 **절대 1 미만이 되지 않는다**.
- **가로는 끝이 없다.** 가로를 자르는 상수·clamp를 새로 만들지 않는다.
- **불감대는 ±80이다.** 보이는 가로 640의 25%다.
- **스프라이트는 정확히 절반이다.** 주인공 28 · 펫 16 · 몬스터 24 · 보스 48.
- **걷는 띠는 y 300~410이고 지평선은 250이다.** 무대 세로는 480.
- **레퍼런스 게임 이름과 고유명을 코드·주석·에셋 이름에 넣지 않는다.** 화풍과 구조만 가져온다.
- **모든 주석과 문서는 한국어다.** 기존 파일의 문체를 따른다.
- **`flutter analyze` 0건**, `flutter test` 전부 통과.
- **새 테스트는 고치기 전 코드에서 실제로 깨져야 한다.** 확인하고 그 출력을 보고에 적는다. 통과만 하는 테스트는 아무것도 안 지킨다 — 이 저장소에서 세 번 나온 실패다.

## 파일 구조

| 파일 | 책임 | 태스크 |
|---|---|---|
| `lib/domain/field.dart` | 무대 좌표 상수와 기하 함수. 가로 경계가 사라진다 | 1 |
| `lib/domain/battle_engine.dart` | 몬스터 나타나는 자리를 주인공 기준으로. 집으로 돌아가는 규칙 삭제 | 1 |
| `lib/domain/game_state.dart` | `heroX` 기본값 0 | 1 |
| `lib/domain/balance_config.dart` | 사거리 절반 | 1 |
| `lib/ui/stage/battle_stage_game.dart` | 배율 규칙 · 불감대 카메라 · 스프라이트 크기 | 2 |
| `lib/ui/stage/battle_stage_game.dart` (`_Background`) | 두 겹 시차 · 가로 되풀이 | 3 |
| `test/domain/field_test.dart` (신규) | 좌표 상수와 `clampToBand` | 1 |
| `test/ui/battle_stage_game_test.dart` | 배율 · 불감대 · 배경 | 2·3 |

---

### Task 1: 도메인 좌표 — 가로를 없애고 세로를 넓힌다

**Files:**
- Modify: `flutter/lib/domain/field.dart` (전면)
- Modify: `flutter/lib/domain/battle_engine.dart:134-200`, `:232-245`, `:506-531`
- Modify: `flutter/lib/domain/game_state.dart:36`
- Modify: `flutter/lib/domain/balance_config.dart:35,37`
- Modify: `flutter/lib/ui/stage/battle_stage_game.dart:20-27` (컴파일 유지용 한 줄)
- Test: `flutter/test/domain/field_test.dart` (신규)

**Interfaces:**
- Produces: `fieldHeight = 480.0` · `heroHomeY = 355.0` · `spawnAheadOfHero = 420.0` · `fieldTopY = 300.0` · `fieldBottomY = 410.0` · `separationRadius = 20.0` · `double clampToBand(double y)` · `distanceBetween`·`moveToward`는 서명 그대로
- Produces: **삭제된 것** — `fieldWidth` · `heroHomeX` · `monsterSpawnX` · `clampToField`. 태스크 2·3은 이 이름들을 쓰면 안 된다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`flutter/test/domain/field_test.dart` 를 새로 만든다.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/field.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

import '../support/catalog.dart';

void main() {
  const c = BalanceConfig();

  group('무대 좌표', () {
    test('걷는 띠가 하단 HUD 위에서 끝난다', () {
      // 하단 바가 논리 69다. 가장 낮은 배율(844×390에서 1.32)에서 세계 52를 가린다.
      // 띠의 아래 끝이 480-52=428보다 위에 있어야 몬스터가 안 가려진다.
      expect(fieldBottomY, lessThan(428));
      expect(fieldTopY, lessThan(fieldBottomY));
      expect(heroHomeY, inInclusiveRange(fieldTopY, fieldBottomY));
    });

    test('세로만 자른다 — 가로는 끝이 없다', () {
      expect(clampToBand(0), fieldTopY);
      expect(clampToBand(9999), fieldBottomY);
      expect(clampToBand(350), 350);
    });

    test('나타나는 자리는 카메라 오른쪽 끝 바깥이다', () {
      // 불감대 ±80 + 보이는 가로의 절반 320 = 주인공+400이 오른쪽 끝의 최댓값.
      expect(spawnAheadOfHero, greaterThan(400));
    });
  });

  group('끝없는 가로', () {
    test('몬스터는 주인공이 어디 있든 그 오른쪽에 나타난다', () {
      final engine = BattleEngine(c, catalog: loadBundledCatalog());
      var s = GameState.initial(c).copyWith(heroX: 5000, wave: const []);
      s = engine.tick(s, 0.016, Random(1));
      expect(s.wave, isNotEmpty, reason: '무리가 생겨야 한다');
      for (final m in s.wave) {
        expect(m.x, greaterThan(5000), reason: '주인공(5000) 오른쪽이어야 한다');
        expect(m.x, lessThan(5000 + spawnAheadOfHero + 100));
      }
    });

    test('무리가 비어도 왼쪽으로 되돌아가지 않는다 — 돌아갈 집이 없다', () {
      // 고치기 전에는 heroHomeX(58)로 100px/s로 되돌아가서 1초면 1134가 됐다.
      // 고친 뒤에는 새 무리가 오른쪽에 생기고 그쪽으로 가거나 제자리에 선다.
      final engine = BattleEngine(c, catalog: loadBundledCatalog());
      var s = GameState.initial(c).copyWith(heroX: 1234, heroY: heroHomeY, wave: const []);
      final before = s.heroX;
      s = engine.tick(s, 1.0, Random(1));
      expect(s.heroX, greaterThanOrEqualTo(before), reason: '왼쪽으로 갔다: ${s.heroX}');
    });

    test('쓰러져도 주인공의 가로 자리는 그대로다', () {
      final engine = BattleEngine(c, catalog: loadBundledCatalog());
      var s = GameState.initial(c).copyWith(heroX: 3000, heroHp: 1);
      for (var i = 0; i < 600 && s.heroHp > 0; i++) {
        s = engine.tick(s, 0.05, Random(7));
      }
      expect(s.heroHp, 0, reason: '쓰러져야 이 테스트가 뜻이 있다');
      expect(s.heroX, greaterThan(2900), reason: '되돌아가면 안 된다');
    });
  });

  test('새 상태의 주인공은 0에서 시작한다', () {
    expect(GameState.initial(c).heroX, 0);
  });

  test('저장을 읽으면 주인공은 0이다 — 절대 위치는 저장할 뜻이 없다', () {
    // heroX는 지금 저장에 없다. 누가 넣으면 이 테스트가 잡는다.
    final json = encodeState(GameState.initial(c).copyWith(heroX: 777));
    expect(decodeState(json)!.heroX, 0);
  });
}
```

`Random` 을 쓰므로 파일 맨 위에 `import 'dart:math';` 를 더한다.

- [ ] **Step 2: 깨지는 것을 확인한다**

Run: `cd flutter && flutter test test/domain/field_test.dart`
Expected: 컴파일 실패. `clampToBand`·`spawnAheadOfHero`·`fieldHeight` 가 없다. **이 출력을 보고에 옮긴다.**

- [ ] **Step 3: `field.dart` 를 다시 쓴다**

`flutter/lib/domain/field.dart` 전체를 아래로 바꾼다.

```dart
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
```

- [ ] **Step 4: `battle_engine.dart` 의 세 곳을 고친다**

**(가) `_move` — 돌아갈 집을 없앤다.** `132`행 근처의 이 부분:

```dart
    final target = s.nearestMonster;
    if (target == null) {
      // 아무도 없으면 제자리로 돌아간다.
      (hx, hy) = moveToward(hx, hy, heroHomeX, heroHomeY, config.heroMoveSpeed * dt);
    } else {
```

를 이렇게 바꾼다.

```dart
    final target = s.nearestMonster;
    // 아무도 없으면 제자리에 선다. 가로가 끝이 없어 돌아갈 집이 없다(스펙 4.3).
    if (target != null) {
```

`else {` 로 시작하던 블록의 여는 중괄호가 위로 올라갔으므로, 그 블록을 닫던 `}` 는 그대로 둔다.

**(나) `_move`·`_separate` 의 `clampToField` 호출 세 곳.**

```dart
      final (cx, cy) = clampToField(mx, my);
      moved.add(m.copyWith(x: cx, y: cy));
```
→
```dart
      moved.add(m.copyWith(x: mx, y: clampToBand(my)));
```

```dart
        final (ax, ay) = clampToField(a.x - nx, a.y - ny);
        final (bx, by) = clampToField(b.x + nx, b.y + ny);
        out[i] = a.copyWith(x: ax, y: ay);
        out[j] = b.copyWith(x: bx, y: by);
```
→
```dart
        out[i] = a.copyWith(x: a.x - nx, y: clampToBand(a.y - ny));
        out[j] = b.copyWith(x: b.x + nx, y: clampToBand(b.y + ny));
```

**(다) `_knockDown` — 가로 자리를 지킨다.** `heroX: heroHomeX,` 줄을 지우고 `heroY: heroHomeY,` 는 남긴다.
주석 한 줄을 그 자리에 더한다: `// 가로 자리는 그대로 둔다 — 되돌아가면 지나온 맵을 다시 걷는다.`

**(라) `_spawnWave` — 주인공 기준으로.**

```dart
            x: monsterSpawnX + (i % 3) * 26,
            y: count == 1 ? heroHomeY : fieldTopY + span * i / (count - 1),
```
→
```dart
            x: s.heroX + spawnAheadOfHero + (i % 3) * 26,
            y: count == 1 ? heroHomeY : fieldTopY + span * i / (count - 1),
```

바로 위 주석 `// 화면 밖 오른쪽에서 세로로 퍼져 들어온다.` 를
`// 주인공의 오른쪽 화면 밖에서 세로로 퍼져 들어온다. 맵이 끝이 없어 절대 좌표가 아니다.` 로 바꾼다.

- [ ] **Step 5: `game_state.dart` 와 `balance_config.dart` 를 고친다**

**지운 이름을 쓰는 곳이 도메인에 세 파일 더 있다.** 전부 고쳐야 컴파일된다.

| 파일:행 | 지금 | 새로 | 근거 |
|---|---|---|---|
| `game_state.dart:36` | `this.heroX = heroHomeX,` | `this.heroX = 0,` | 절대 위치가 뜻이 없다. 0에서 시작 |
| `game_state.dart:72` | `x: monsterSpawnX + i * 22,` | `x: spawnAheadOfHero + i * 22,` | 첫 무리. 주인공이 0이라 주인공+420 = 420 |
| `save_codec.dart:155` | `x: monsterSpawnX,` | `x: spawnAheadOfHero,` | 옛 저장에서 무리를 되살릴 때. heroX는 저장에 없어 0이다 |
| `monster_unit.dart:60` | `?? monsterSpawnX,` | `?? spawnAheadOfHero,` | x가 없는 옛 저장의 폴백 |

이 넷이 전부인지 `grep -rn "heroHomeX\|monsterSpawnX\|clampToField\|fieldWidth" lib/` 로 확인하고
결과가 비어 있는 것을 보고에 적는다.

`balance_config.dart`:
```dart
    this.heroAttackRange = 42,      →  this.heroAttackRange = 21,
    this.monsterAttackRange = 36,   →  this.monsterAttackRange = 18,
```
두 줄 위에 주석을 더한다: `// 사거리는 몸 크기에 묶인다. 스프라이트가 절반이 되어 같이 절반이다(0.75몸 유지).`

**`balance.json` 은 안 건드린다.** 서버가 이 값을 모르고, 클라이언트 폴백이 기본값을 쓴다(백로그 D6-1).
`lib/data/balance_codec.dart` 에 이 두 값의 폴백이 있으면 같이 고친다 — `grep -n "AttackRange" lib/data/balance_codec.dart` 로 확인한다.

- [ ] **Step 6: `battle_stage_game.dart` 가 컴파일되게 한 줄만 고친다**

`20`행 근처:
```dart
const stageWidth = fieldWidth;
```
→
```dart
// 태스크 2가 배율 규칙으로 갈아 치운다. 지금은 컴파일만 유지한다.
const stageWidth = 640.0;
```

`stageHeight = fieldHeight` 는 그대로 둔다(480이 된다).

- [ ] **Step 7: 새 테스트가 통과하는지 본다**

Run: `cd flutter && flutter test test/domain/field_test.dart`
Expected: PASS 8건.

- [ ] **Step 8: 전체를 돌리고 깨진 것을 고친다**

Run: `cd flutter && flutter analyze && flutter test`

**지운 이름을 쓰는 테스트가 여섯 파일이다.** 컴파일부터 안 된다. 이렇게 고친다.

| 파일:행 | 지금 | 새로 |
|---|---|---|
| `test/domain/dungeon_test.dart:113` | `x: heroHomeX + 20` | `x: 20` (주인공이 0이다) |
| `test/domain/save_codec_test.dart:22` | `x: heroHomeX + 20` | `x: 20` |
| `test/domain/battle_engine_test.dart:120` | `x: heroHomeX + 20` | `x: 20` |
| `test/domain/combat_test.dart:34,38` | `monsterSpawnX` | `spawnAheadOfHero` |
| `test/domain/combat_test.dart:165` | `expect(down.heroX, heroHomeX, reason: '집으로 돌아간다')` | **규칙이 바뀐 자리다.** 쓰러지기 직전 `heroX`를 잡아 두고 `expect(down.heroX, before, reason: '가로 자리는 그대로다')` |
| `test/ui/battle_stage_game_test.dart:64,87,89,108,117,158,182` | `monsterSpawnX`·`heroHomeX`·`stageWidth` | 64·89: `spawnAheadOfHero`·`640` · 87: `greaterThan(0)` · 108·117: `x: 20` · **158·182는 옛 카메라(cover·clamp) 테스트라 태스크 2가 갈아 치운다 — 여기서는 `stageWidth` 를 640으로만 바꿔 컴파일되게 한다** |

좌표와 사거리가 바뀌었으므로 그 밖의 기존 테스트도 깨질 수 있다. **깨진 테스트를 그냥 숫자만 맞추지 마라.**
각각에 대해 (가) 좌표계가 바뀌어 기대값만 바뀌는 것인지, (나) 규칙이 실제로 달라진 것인지 판단하고
보고에 하나씩 적어라. `test/domain/wall_simulation_test.dart` 와 `test/domain/combat_test.dart` 가
층 진행을 재는데, **층 진행 속도가 눈에 띄게 바뀌면 그것은 밸런스 변화이므로 보고에 명시하고 멈춰라.**

- [ ] **Step 9: 커밋**

```bash
cd flutter && git add -A && git commit -m "feat: 무대 좌표에서 가로 경계를 없앤다

주인공이 몬스터를 맞이하러 오른쪽으로 나아가고 되돌아오지 않는다.
몬스터는 절대 좌표가 아니라 주인공 기준으로 나타난다. 세로는 480으로
넓히고 걷는 띠를 300~410에 둔다 — 하단 HUD가 가리지 않는 자리다.

사거리는 몸 크기에 묶여 있어 스프라이트가 절반이 되는 만큼 같이 절반으로 줄인다.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 2: 배율 규칙과 불감대 카메라

**Files:**
- Modify: `flutter/lib/ui/stage/battle_stage_game.dart:19-45`, `:99-105`, `:110-118`, `:158-200`
- Test: `flutter/test/ui/battle_stage_game_test.dart`

**Interfaces:**
- Consumes: 태스크 1의 `fieldHeight`(480) · `heroHomeY`(355). `fieldWidth`·`heroHomeX`·`monsterSpawnX` 는 **없다**.
- Produces: `viewWidth = 640.0` · `viewHeight = 480.0` · `cameraDeadZone = 80.0` · `BattleStageGame.heroPixelSize`(28) · `BattleStageGame.petPixelSize`(16). 태스크 3이 `viewWidth`·`viewHeight` 를 쓴다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`flutter/test/ui/battle_stage_game_test.dart` 의 `main()` 안, 기존 `boot()` 정의 **아래**에 더한다.
`boot()` 이 `game.onGameResize(Vector2(360, 270))` 로 고정돼 있으므로, 창 크기를 받는 새 도우미를 만든다.

```dart
  Future<BattleStageGame> bootAt(double w, double h) async {
    final game = BattleStageGame(catalog: loadBundledCatalog(), config: c, loader: _NoAssetLoader());
    game.onGameResize(Vector2(w, h));
    await game.onLoad();
    game.onMount();
    await game.ready();
    game.update(0);
    return game;
  }

  group('배율', () {
    test('보이는 상자 640x480을 덮는 최소 배율이다', () async {
      for (final (w, h) in const [(844.0, 390.0), (832.0, 610.0), (1280.0, 800.0)]) {
        final game = await bootAt(w, h);
        game.update(1 / 60);
        expect(
          game.camera.viewfinder.zoom,
          closeTo(max(w / viewWidth, h / viewHeight), 0.001),
          reason: '$w×$h',
        );
      }
    });

    test('배율은 1 아래로 안 내려간다 — 원본 픽셀이 버려진다', () async {
      // 640×480보다 작은 창. 상자를 덮는 배율은 0.625지만 1로 묶여야 한다.
      final game = await bootAt(400, 300);
      game.update(1 / 60);
      expect(game.camera.viewfinder.zoom, 1.0);
    });

    test('주인공이 화면 가로에서 차지하는 비율이 창 모양과 무관하다', () async {
      // 이것이 사용자가 지적한 문제를 그대로 재는 테스트다.
      // 셋 다 4:3보다 가로로 긴 창이라 가로가 배율을 정한다.
      // 4:3보다 세로로 긴 창은 세로가 정하므로 이 목록에 넣으면 안 된다.
      final ratios = <double>[];
      for (final (w, h) in const [(844.0, 390.0), (832.0, 610.0), (1280.0, 800.0)]) {
        final game = await bootAt(w, h);
        game.update(1 / 60);
        ratios.add(BattleStageGame.heroPixelSize * game.camera.viewfinder.zoom / w);
      }
      for (final r in ratios) {
        expect(r, closeTo(0.044, 0.002), reason: '레퍼런스 실측 3.1~4.8% 안이어야 한다: $ratios');
      }
    });
  });

  group('불감대 카메라', () {
    test('주인공이 상자 안에서 움직이면 카메라가 안 움직인다', () async {
      final game = await bootAt(832, 610);
      game.update(1 / 60);
      final before = game.camera.viewfinder.position.x;
      // pos만 바꾸면 액터가 target으로 걸어 되돌아간다. 둘 다 옮긴다.
      game.hero!.pos.x = before + cameraDeadZone - 5;
      game.hero!.target.x = game.hero!.pos.x;
      game.update(1 / 60);
      expect(game.camera.viewfinder.position.x, closeTo(before, 0.01));
    });

    test('상자를 벗어나면 딱 그만큼 밀린다', () async {
      final game = await bootAt(832, 610);
      game.update(1 / 60);
      final before = game.camera.viewfinder.position.x;
      game.hero!.pos.x = before + cameraDeadZone + 40;
      game.hero!.target.x = game.hero!.pos.x;
      game.update(1 / 60);
      expect(
        game.camera.viewfinder.position.x,
        closeTo(game.hero!.pos.x - cameraDeadZone, 0.01),
        reason: '주인공이 상자 오른쪽 벽에 붙어 있어야 한다',
      );
    });

    test('세로는 바닥에 붙는다 — 남는 자리는 하늘이 더 보인다', () async {
      for (final (w, h) in const [(844.0, 390.0), (832.0, 610.0)]) {
        final game = await bootAt(w, h);
        game.update(1 / 60);
        final visibleH = h / game.camera.viewfinder.zoom;
        expect(
          game.camera.viewfinder.position.y,
          closeTo(fieldHeight - visibleH / 2, 0.01),
          reason: '$w×$h — 아래 끝이 무대 바닥(480)에 닿아야 한다',
        );
      }
    });

    test('무리가 걸어 들어오는 동안에도 주인공이 화면 가운데 상자 안에 있다', () async {
      // 사용자가 지적한 "캐릭터가 화면 밖으로 나간다"를 그대로 재는 테스트다.
      // 고치기 전에는 카메라가 무대 가장자리에 묶여 주인공이 상자 밖으로 밀렸다.
      final game = await bootAt(832, 610);
      game.sync(GameState.initial(c));
      await settle(game, frames: 30);
      final camX = game.camera.viewfinder.position.x;
      expect((game.hero!.pos.x - camX).abs(), lessThanOrEqualTo(cameraDeadZone + 1),
          reason: '주인공 ${game.hero!.pos.x}, 카메라 $camX');
    });

    test('주인공이 아무리 멀리 가도 카메라가 따라간다 — 가장자리가 없다', () async {
      final game = await bootAt(832, 610);
      game.update(1 / 60);
      game.hero!.pos.x = 10000;
      game.hero!.target.x = 10000;
      game.update(1 / 60);
      expect(game.camera.viewfinder.position.x, closeTo(10000 - cameraDeadZone, 0.01));
    });
  });
```

`max` 를 쓰므로 파일 맨 위 `import 'dart:math';` 가 이미 있는지 확인한다(있다).
`viewWidth`·`viewHeight`·`cameraDeadZone`·`fieldHeight` 를 쓰므로 import 두 줄이 이미 있다(`field.dart`, `battle_stage_game.dart`).

- [ ] **Step 2: 깨지는 것을 확인한다**

Run: `cd flutter && flutter test test/ui/battle_stage_game_test.dart`
Expected: 컴파일 실패 — `viewWidth`·`cameraDeadZone`·`heroPixelSize` 가 없다. **출력을 보고에 옮긴다.**

- [ ] **Step 3: 상수를 바꾼다**

`battle_stage_game.dart` 의 `19-45`행 부근. `stageWidth`·`stageHeight`·`normalZoomFactor` 를 지우고 아래로 바꾼다.

```dart
/// 화면에 반드시 보이는 세계의 크기. 배율은 이 상자를 덮는 최소값이다.
///
/// 이렇게 두면 **캐릭터가 화면 가로에서 차지하는 비율이 창 모양과 무관해진다**.
/// 2026-09-05까지는 무대 전체를 채우는 방식(cover)이라 세로로 긴 창에서 배율이 3.50까지 튀어
/// 보이는 가로가 238로 줄었고, 폭 360인 무대가 아예 안 들어와 캐릭터가 화면 밖으로 나갔다.
///
/// 640은 주인공 28픽셀이 가로에 22.9마리 들어가는 값이다(레퍼런스 실측 25~30마리).
/// 480은 4:3 창까지 가로가 배율을 정하게 하는 값이다. 그보다 세로로 긴 창은 지원 범위 밖이다.
const viewWidth = 640.0;
const viewHeight = 480.0;

/// 카메라가 안 움직이는 상자의 반지름. 보이는 가로 640의 25%다.
///
/// 주인공이 이 안에서 움직이면 카메라가 가만히 있고, 벗어나면 맵이 같이 밀린다.
/// 붙어 따라다니면 걸음마다 배경이 흔들려 어지럽다.
const cameraDeadZone = 80.0;

/// 배경 그리기가 쓰는 무대 세로. 가로는 끝이 없다(field.dart).
const stageHeight = fieldHeight;
```

스프라이트 크기 상수를 절반으로 바꾼다.

```dart
const _heroSheetId = 'warrior_1';
const _heroSize = 28;
const _bossSheetId = 'forest';
const _bossSize = 48;
const _monsterSize = 24;
const _petSize = 16;
```

`onLoad` 안에서 펫이 `size: 32`, `pixelSize: 32` 로 박혀 있다. 둘 다 `_petSize` 로 바꾼다.
펫이 주인공 뒤에 서는 자리 `_heroHome + Vector2(-24, 12)` 와 `update` 안의
`_pet?.target.setValues(hero.pos.x - 26, hero.pos.y + 12)` 도 몸이 절반이 되었으니 절반으로 줄인다 —
`Vector2(-12, 6)`, `(hero.pos.x - 13, hero.pos.y + 6)`.

`_heroHome` 은 `Vector2(heroHomeX, heroHomeY)` 인데 `heroHomeX` 가 사라졌다.
`static final _heroHome = Vector2(0, heroHomeY);` 로 바꾼다.

조회용 접근자에 둘을 더한다(기존 `monsterPixelSize` 옆).

```dart
  static const heroPixelSize = _heroSize;
  static const petPixelSize = _petSize;
```

- [ ] **Step 4: 배율과 카메라를 바꾼다**

`_cover` 게터(`99-105`행)를 지우고 아래로 바꾼다.

```dart
  /// 보이는 상자를 덮는 최소 배율. 1 아래로 내려가지 않는다 —
  /// 1 미만이면 원본 픽셀이 통째로 버려져 계단이 무너진다.
  double get _zoom {
    final vp = camera.viewport.size;
    return math.max(1.0, math.max(vp.x / viewWidth, vp.y / viewHeight));
  }
```

`onLoad` 안의 카메라 초기화(`110-118`행 부근)를 바꾼다.

```dart
    camera.viewfinder.anchor = Anchor.center;
    // 첫 프레임이 튀지 않게 제자리를 잡아 둔다. 이후는 _moveCamera가 이어받는다.
    camera.viewfinder.zoom = _zoom;
    camera.viewfinder.position = Vector2(0, stageHeight - camera.viewport.size.y / _zoom / 2);
```

`_moveCamera`(`158-200`행) 전체를 바꾼다.

```dart
  /// 카메라를 주인공에 붙인다. 불감대 밖으로 나갈 때만 맵이 같이 밀린다.
  ///
  /// 붙어 따라다니면 걸음마다 배경이 흔들린다. 상자 안에서는 주인공만 움직이고
  /// 상자 벽에 닿을 때 비로소 맵이 흐른다. 가장자리에서 멈추는 처리는 없다 — 가로는 끝이 없다.
  void _moveCamera(double dt) {
    final target = _cameraTarget;
    if (target == null) return;

    final zoom = _zoom;
    camera.viewfinder.zoom = zoom;

    var camX = camera.viewfinder.position.x;
    final x = target.pos.x;
    if (x > camX + cameraDeadZone) camX = x - cameraDeadZone;
    if (x < camX - cameraDeadZone) camX = x + cameraDeadZone;

    // 세로는 바닥에 붙인다. 땅이 항상 화면 아래에 오고,
    // 세로로 남는 자리는 하늘이 더 보이는 것으로 채워진다.
    final camY = stageHeight - camera.viewport.size.y / zoom / 2;
    camera.viewfinder.position = Vector2(camX, camY);
  }

  /// 카메라가 따라가는 대상.
  ///
  /// 레퍼런스는 캐릭터가 셋이라 유저가 고른다. 우리는 아직 주인공 하나뿐이라 고를 것이 없다.
  /// 파티가 셋이 되면(백로그 F절) 이 값만 갈아 끼우면 된다.
  StageActor? get _cameraTarget => _hero;
```

**지워지는 것**: 보스일 때 물러나던 처리(`wantedZoom`·`normalZoomFactor`), 지수 감쇠 추적(`k = 1 - math.exp(-dt * 3.2)`), 가장자리 clamp 네 줄, "무대에 들어온 몬스터만 따라간다"는 `front` 탐색. 배율이 고정이고 보이는 가로가 640이라 48픽셀 보스는 여유롭게 들어간다.

`dt` 를 더 안 쓰면 analyze가 경고한다. 서명을 `void _moveCamera()` 로 바꾸고 `update` 의 호출도 같이 고친다.

- [ ] **Step 5: 통과를 확인한다**

Run: `cd flutter && flutter test test/ui/battle_stage_game_test.dart`
Expected: 새 테스트 8건 PASS.

- [ ] **Step 6: 전체를 돌린다**

Run: `cd flutter && flutter analyze && flutter test`

`stageWidth` 상수가 사라졌으므로 89행 근처 `expect(m.pos.x, lessThan(stageWidth), reason: '화면 안으로 들어왔다')` 는
보이는 오른쪽 끝으로 바꾼다:
`lessThan(game.camera.viewfinder.position.x + game.camera.viewport.size.x / game.camera.viewfinder.zoom / 2)`.

**옛 카메라를 재는 테스트 둘을 지운다** — `test/ui/battle_stage_game_test.dart` 의 158행 근처
(`stageWidth - halfW` 로 가장자리 clamp를 재는 것)와 182행 근처(`cover = max(vp.x / stageWidth, ...)` 로
cover 배율을 재는 것). 둘 다 이 태스크가 없앤 규칙을 주장한다. 새 규칙은 위 Step 1의 테스트가 잰다.

기존 무대 테스트가 `boot()` 의 360×270 창을 쓴다. 그 창에서는 배율이 1로 묶여 보이는 세계가 360×270이 되고
불감대 ±80이 그 안에서 성립하므로 대부분 그대로 통과할 것이다. 깨지는 것이 있으면 `boot()` 의 창을
`Vector2(832, 610)` 으로 바꾸고, 그 때문에 바뀌는 기대값을 하나씩 판단해 고친다.
좌표가 바뀐 것인지 규칙이 바뀐 것인지 보고에 적는다.

- [ ] **Step 7: 커밋**

```bash
cd flutter && git add -A && git commit -m "feat: 배율을 640x480 상자에 고정하고 카메라에 불감대를 둔다

캐릭터가 화면 가로에서 차지하는 비율이 창 모양과 무관하게 4.4%가 된다.
832x610 창에서 23.6%였다 — 무대가 화면에 안 들어와 캐릭터가 밖으로 나갔다.

카메라는 주인공에 붙되 +-80 상자 안에서는 안 움직인다. 벗어날 때만 맵이
같이 밀린다. 가장자리에서 멈추는 처리를 없앴다 - 가로는 끝이 없다.
세로는 바닥에 붙여 남는 자리를 하늘로 채운다.

스프라이트를 정확히 절반으로 그린다. 원본은 아직 옛 크기라 임시로
줄여 그리는 것이고, 새 아트가 오면 같은 값에서 1대1이 된다.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 3: 배경 두 겹과 시차, 가로 되풀이

**Files:**
- Modify: `flutter/lib/ui/stage/battle_stage_game.dart` (`_Background` 클래스 전체)
- Test: `flutter/test/ui/battle_stage_game_test.dart`

**Interfaces:**
- Consumes: 태스크 2의 `viewWidth`(640) · `stageHeight`(480) · `camera.viewfinder`
- Produces: `_Background.horizon`(250.0) · `farParallax`(0.35). 이 태스크에서 끝난다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test/ui/battle_stage_game_test.dart` 에 더한다.

```dart
  group('배경', () {
    test('지평선이 걷는 띠 위에 있다', () {
      expect(BattleStageGame.horizon, lessThan(fieldTopY));
      expect(BattleStageGame.horizon, greaterThan(stageHeight * 0.4),
          reason: '하늘이 너무 얇으면 3/4 시점이 안 산다');
    });

    test('주인공이 멀리 가도 배경이 그려진다 — 가로로 되풀이한다', () async {
      final game = await bootAt(832, 610);
      game.update(1 / 60);
      game.hero!.pos.x = 12345;
      game.hero!.target.x = 12345;
      game.update(1 / 60);
      // 카메라가 따라간 자리에서 배경이 덮는 가로 구간을 계산해 본다.
      final camX = game.camera.viewfinder.position.x;
      final half = 832 / game.camera.viewfinder.zoom / 2;
      final tiles = BattleStageGame.backgroundTilesFor(camX - half, camX + half, 1.0);
      expect(tiles, isNotEmpty);
      expect(tiles.first, lessThanOrEqualTo(camX - half));
      expect(tiles.last + viewWidth, greaterThanOrEqualTo(camX + half));
    });

    test('먼 겹은 카메라의 0.35만큼만 흐른다', () {
      // 타일 첫 좌표는 640마다 뛰므로 그 자체를 비교하면 뜻이 없다.
      // 화면에 대한 타일 격자의 위상(첫 타일 - 화면 왼쪽)이 카메라 이동에 얼마나 반응하는지 잰다.
      // 이동을 100으로 두어 한 타일(640) 안에서 재고, 겹침(wrap)이 끼지 않게 한다.
      double phase(double left, double p) => BattleStageGame.backgroundTilesFor(left, left + 640, p).first - left;
      final nearShift = phase(100, 1.0) - phase(0, 1.0);
      final farShift = phase(100, farParallax) - phase(0, farParallax);
      expect(nearShift, closeTo(-100, 0.001), reason: '땅 겹은 카메라와 같이 흐른다');
      expect(farShift, closeTo(-100 * farParallax, 0.001), reason: '먼 겹은 0.35만 흐른다');
    });
  });
```

- [ ] **Step 2: 깨지는 것을 확인한다**

Run: `cd flutter && flutter test test/ui/battle_stage_game_test.dart --plain-name 배경`
Expected: 컴파일 실패 — `BattleStageGame.horizon`·`backgroundTilesFor`·`farParallax` 가 없다.

- [ ] **Step 3: 타일 자리를 세는 함수를 만든다**

`BattleStageGame` 클래스 안에 정적 함수를 더한다. 순수 함수라 테스트가 쉽다.

```dart
  /// [left]~[right] 세계 구간을 덮는 타일들의 왼쪽 x. 타일 폭은 [viewWidth]다.
  ///
  /// [parallax]가 1이면 카메라와 같이 흐르고, 작을수록 천천히 흐른다.
  /// 먼 것이 천천히 지나가야 깊이가 보인다 — 1로 두면 배경이 통째로 붙어 평면이 된다.
  static List<double> backgroundTilesFor(double left, double right, double parallax) {
    // 시차: 겹을 카메라 이동의 (1 - parallax)만큼 되끌어 준다.
    final shift = left * (1 - parallax);
    final first = ((left - shift) / viewWidth).floorToDouble() * viewWidth + shift;
    final out = <double>[];
    for (var x = first; x < right; x += viewWidth) {
      out.add(x);
    }
    return out;
  }

  static const horizon = _Background.horizon;
```

파일 아래쪽 상수 자리에 더한다.

```dart
/// 먼 겹이 흐르는 속도. 1이면 카메라와 같이 붙어 움직여 평면으로 보인다.
const farParallax = 0.35;
```

- [ ] **Step 4: `_Background` 를 다시 쓴다**

`_Background` 클래스 전체를 아래로 바꾼다. 카메라 자리를 알아야 하므로 게임 참조를 받는다.

```dart
/// 배경 — 먼 겹과 땅 겹. 가로로 끝없이 되풀이한다.
///
/// 한 장 걸러 좌우를 뒤집어 붙인다. 지금 그림은 좌우가 안 이어지므로 그냥 늘어놓으면
/// 640마다 이음매가 보인다. 뒤집으면 이음매가 사라지고, 숲이라 뒤집혀도 어색하지 않다.
class _Background extends PositionComponent {
  _Background(this.game) : super(priority: -1000);

  final BattleStageGame game;

  /// 지평선 y. 하늘이 절반을 조금 넘는다 — 3/4 시점에서 땅이 좁으면 전투가 눌린다.
  static const horizon = 250.0;

  final _pixel = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  String? region;
  ui.Image? _far, _ground;
  Color? _veil;

  Future<void> setRegion(String? regionId, Images images) async {
    region = regionId;
    if (regionId == null) {
      _far = null;
      _ground = null;
      return;
    }
    final own = _regionsWithBackground.contains(regionId);
    try {
      final source = own ? regionId : 'forest';
      final far = await images.load('$source/far.png');
      final ground = await images.load('$source/ground.png');
      if (region != regionId) return;
      _far = far;
      _ground = ground;
      _veil = own ? null : regionColors(regionId).last.withValues(alpha: 0.5);
    } on Object {
      _far = null;
      _ground = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final vp = game.camera.viewport.size;
    final zoom = game.camera.viewfinder.zoom;
    final center = game.camera.viewfinder.position;
    final halfW = vp.x / zoom / 2;
    final left = center.x - halfW;
    final right = center.x + halfW;

    final far = _far, ground = _ground;
    if (far == null || ground == null) {
      _renderGradient(canvas, left, right);
      return;
    }
    // 하늘은 지평선 위 전부, 땅은 지평선 아래 전부. 그림을 늘려 채운다 —
    // 지금 그림(360×110·360×160)은 이 크기가 아니다. 새 타일이 오면 늘리기가 1대1이 된다.
    _tile(canvas, far, BattleStageGame.backgroundTilesFor(left, right, farParallax), 0, horizon);
    _tile(canvas, ground, BattleStageGame.backgroundTilesFor(left, right, 1.0), horizon, stageHeight - horizon);

    final veil = _veil;
    if (veil != null) {
      canvas.drawRect(Rect.fromLTWH(left, 0, right - left, stageHeight), Paint()..color = veil);
    }
  }

  /// 한 겹을 늘어놓는다. 한 장 걸러 좌우를 뒤집어 이음매를 없앤다.
  void _tile(Canvas canvas, ui.Image image, List<double> xs, double top, double height) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    for (final x in xs) {
      final flip = (x / viewWidth).round().isOdd;
      canvas.save();
      if (flip) {
        canvas.translate(x + viewWidth, 0);
        canvas.scale(-1, 1);
        canvas.drawImageRect(image, src, Rect.fromLTWH(0, top, viewWidth, height), _pixel);
      } else {
        canvas.drawImageRect(image, src, Rect.fromLTWH(x, top, viewWidth, height), _pixel);
      }
      canvas.restore();
    }
  }

  void _renderGradient(Canvas canvas, double left, double right) {
    final rect = Rect.fromLTWH(left, 0, right - left, stageHeight);
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, regionColors(region)),
    );
    canvas.drawRect(
      Rect.fromLTWH(left, horizon, right - left, stageHeight - horizon),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }
}
```

`final _bg = _Background();` 를 `late final _bg = _Background(this);` 로 바꾼다.

**주의**: `_Background` 는 `_root` 안에 있고 `_root` 는 `world` 안이라 좌표가 세계 좌표다.
`render` 가 계산한 `left`·`right` 가 세계 좌표이므로 그대로 그리면 맞는다.

- [ ] **Step 5: 통과를 확인한다**

Run: `cd flutter && flutter test test/ui/battle_stage_game_test.dart`
Expected: 배경 3건을 포함해 전부 PASS.

- [ ] **Step 6: 눈으로 본다**

Run: `cd flutter && flutter run -d macos`

**보고에 답해야 할 것 넷.**
1. 창을 세로로 길게·가로로 넓게 바꿔 가며 캐릭터 크기가 그대로인가.
2. 주인공과 몬스터가 항상 화면 안에 있는가.
3. 주인공이 걸을 때 배경이 흐르는가. 불감대 안에서는 안 흔들리는가.
4. **걷기 애니메이션이 미끄러지는가.** 몸이 절반이라 같은 속도면 다리 회전보다 두 배 빨라 보일 수 있다.
   미끄러지면 `balance_config.dart` 의 `heroMoveSpeed` 100→70, `monsterMoveSpeed` 160→110으로 줄이고
   그 이유를 커밋 메시지에 적어라. 안 미끄러지면 **건드리지 마라** — 근거 없이 숫자를 바꾸면 그것이 굳는다.

- [ ] **Step 7: 전체를 돌리고 커밋**

```bash
cd flutter && flutter analyze && flutter test && git add -A && git commit -m "feat: 배경을 두 겹 시차로 가로 되풀이한다

주인공이 끝없이 나아가므로 배경도 끝없이 이어져야 한다. 640마다 한 장씩
늘어놓되 한 장 걸러 좌우를 뒤집어 이음매를 없앤다. 먼 겹은 카메라의 0.35로
흘러 깊이를 만든다.

지금 그림(360x110, 360x160)은 새 크기가 아니라 늘려 쓴다. 좌우가 이어지는
타일을 발주하면 늘리기가 1대1이 되고 뒤집기도 뺄 수 있다.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

## 이 계획이 끝나면

앱으로 크기를 확인한 뒤 별도 계획으로 간다(스펙 9절 4·5단계).

1. 픽셀랩으로 24픽셀 몬스터를 두세 개 시험 발주하고 `ART_GUIDE.md` 의 읽힘 규칙을 새 크기로 고쳐 쓴다.
   지금 지침은 48픽셀 기준이라 "특징은 8px 이상"이 24픽셀에서는 몸의 1/3이 된다.
2. 스프라이트 여섯 장(주인공 2·펫 1·몬스터 2·보스 1)과 좌우가 이어지는 배경 타일을 발주해 갈아 끼운다.

`docs/BACKLOG.md` 의 D13이 이 작업이다. 계획이 끝나면 D13을 "코드 완료, 아트 발주 남음"으로 고친다.

---

## 실행 기록 (2026-09-06)

브랜치 `feat/wide-stage`, 커밋 5개. Flutter 350 → 371, analyze 0건.

**이 계획이 틀렸던 곳**

1. **스펙 5절 "층 진행 속도에 영향이 없다"가 거짓이었다.** 태스크 1 리뷰가 wall_simulation으로 40층 5.5분 → 8.6분(+56%)을 잡았다.
   옛 무대는 폭이 막혀 있어 주인공이 x≈370에 이르면 다음 무리가 코앞(400)에 나타났다 — 접근 시간이 0이었다.
   나타나는 거리를 420 → 260으로 내려 7.1분(+29%)까지 회복했고 남은 것은 백로그 D14다. **검증 없이 적은 문장이었다.**
2. **나타나는 거리 420은 생기지 않는 경우를 가정했다.** "주인공이 불감대 왼쪽 벽에 붙은" 경우인데 주인공은 오른쪽으로만 움직인다.
   카메라는 항상 주인공−80에 끌려가므로 보이는 오른쪽 끝은 주인공+240이고, 260이면 충분하다.
   카메라 시작 x도 −80으로 두어 첫 무리부터 같은 논리가 성립하게 했다.
3. **스펙 4.3 "저장을 읽을 때 x를 0으로 되돌린다"가 Critical을 만들었다.** 무리 x는 절대 좌표로 살아나서 40층 저장을 읽으면
   첫 접전까지 64초를 빈 맵을 걷고, 78층부터는 로드마다 층 실패가 먼저 터진다. heroX를 저장하는 것으로 뒤집었다 —
   절대 위치는 뜻이 없어도 무리와의 상대 위치는 뜻이 있다.
4. **이펙트 파일이 어느 태스크의 Files에도 없었다.** 참격·넉백·파티클·데미지 숫자가 세계 좌표인데 스프라이트가 절반이 되니
   참격 호가 몬스터 몸의 3.7배가 되고 데미지 숫자는 반대로 화면 26px → 9.8px로 줄었다. 전체 리뷰가 잡았다.
5. **반전 패리티를 세계 x로 정한 것이 틀렸다.** 시차 겹의 x는 카메라에 비례해 연속으로 변하므로 카메라가 3만 움직여도 뒤집혀
   약 10초마다 먼 배경 전체가 좌우 반전됐다. 태스크 3 리뷰가 "경계에 안 붙는다"고 Minor로 낮췬 근거가 틀렸다.
   겹 자체 공간의 타일 번호로 정하는 `flippedAt` 으로 바꿨다.
6. **사거리 폴백이 기본값과 원래부터 달랐다.** `balance_codec` 폴백 34/28 vs `BalanceConfig` 42/36 — 테스트와 실서비스가
   다른 사거리로 돌고 있었다. 21/18 하나로 맞췼다.
7. **태스크 1의 "고치기 전 깨짐" 확인 테스트 하나가 무의미했다** — 계획 작성 중 스스로 잡아 고쳤다(1초 이동으로 되돌아가면 깨지게).
8. **구현자 세션이 커밋 뒤 끊겨 리포트 없이 태스크 1이 끝났다.** 리뷰어에게 되돌리기 확인을 직접 시켜 메웠다.

**사용자 두 지적은 풀렸다** — 832×610·844×390에서 주인공이 화면 가로의 4.4%로 같고, 무리가 들어오는 동안 프레임 안이다(PNG로 확인).

**남은 것** — 걷기 애니메이션이 사이클당 2.7몸(옛 1.34몸)으로 미끄러져 보인다. 속도를 줄이면 D14가 커진다.
새 28픽셀 시트의 fps로 맞추는 것이 답이라 아트 발주 계획(스펙 9절 4·5단계)으로 넘겼다. 사용자가 병합된 앱에서 본다.
