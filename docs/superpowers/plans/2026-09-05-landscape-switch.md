# 가로 전환 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 게임을 세로 고정에서 가로 고정으로 바꾸고, 무대 비율과 배경 지평선을 가로에 맞게 다시 잡는다. **화면이 안 깨지고 돌아가는 것까지**가 이 계획의 끝이다.

**Architecture:** 네 겹이다. ① `main.dart`의 방향 고정 ② 무대 상수 ③ **카메라를 레터박스에서 cover로** ④ 배경 그리기(지평선 비율). 여기에 세로를 전제한 테스트의 화면 크기를 고친다. **자리 재배치는 이 계획이 아니다** — `game_screen.dart`의 좌표는 어긋나 보여도 그대로 두고, 다음 계획에서 일곱 자리로 옮긴다.

**Tech Stack:** Flutter + Flame. `CameraComponent.withFixedResolution`.

**Spec:** `docs/superpowers/specs/2026-09-05-screen-map-design.md` (1절 가로 전환)

## Global Constraints

- **무대 가상 가로는 `360`을 유지한다.** 스프라이트 크기(주인공 56 · 몬스터 48 · 보스 96)가 이 폭을 전제로 정해졌다(`2026-09-03-art-pipeline-design.md` §1). 폭을 바꾸면 아트 규격이 통째로 흔들린다
- **픽셀 확대는 최근접 보간, 액터 위치는 정수 픽셀 반올림.** 지금 규칙을 그대로 지킨다
- 배경 파일(`far.png` 360×110, `ground.png` 360×160)은 **다시 그리지 않는다.** 자르거나 조합만 바꾼다
- 문체는 기존 코드 주석을 따른다 — 평서형, 짧게, 존댓말 없음
- **`game_screen.dart`의 자리 좌표는 건드리지 않는다.** 이 계획의 범위 밖이다

## File Structure

| 파일 | 책임 | 처리 |
|---|---|---|
| `flutter/lib/main.dart` | 앱 시작·방향 고정 | `portraitUp` → 가로 |
| `flutter/lib/ui/stage/battle_stage_game.dart` | 무대 상수·카메라·배경 그리기 | 상수 + **카메라 cover** + `_Background.render` |
| `flutter/lib/domain/field.dart` | 전투 판의 크기와 자리 (도메인) | **실행 중 추가** — 세로 값이 남아 캐릭터가 무대 밖에 있었다 |
| `flutter/test/ui/game_screen_test.dart` | 화면 테스트 | 화면 크기를 가로로 |
| `flutter/test/ui/art_gallery_test.dart` | 캡처 내보내기 | 화면 크기를 가로로 |
| `flutter/test/ui/codex_screen_test.dart` | 도감 테스트 | 화면 크기를 가로로 |
| `GAME_DESIGN.md` 1장 | 기획 정본 | `세로 고정` → `가로 고정` + 근거 |
| `docs/BACKLOG.md` D2 | 남은 일 | 규격을 가로로 (삭제 아님) |

**코드 파일은 둘뿐이다.** 나머지는 테스트와 문서다.

---

### Task 1: 방향과 무대 비율

**Files:**
- Modify: `flutter/lib/main.dart` (방향 고정)
- Modify: `flutter/lib/ui/stage/battle_stage_game.dart:21-30` (상수 4개)
- Modify: `flutter/test/ui/game_screen_test.dart:25,82,98`
- Modify: `flutter/test/ui/codex_screen_test.dart:15`
- Modify: `flutter/test/ui/art_gallery_test.dart:101`

**Interfaces:**
- Consumes: 없음
- Produces: `stageHeight` · `viewHeight` 새 값. Task 2의 배경 그리기가 이 값을 쓴다

**왜 이 값인가**: 무대를 **`360×202`(약 16:9)**로 잡는다. 요즘 폰 가로가 16:9~20:9 사이의 한가운데다.

**Task 2에서 카메라를 cover(화면을 꽉 채우고 남는 쪽을 자름)로 바꾸므로 검은 띠는 안 생긴다.** 대신 기기 비율에 따라 잘리는 방향이 다르다 — 20:9 폰은 위아래가, 4:3 태블릿은 좌우가 잘린다. **안전 영역은 가운데 `269×162`**다. 그 밖은 어느 기기에선가 잘릴 수 있다. 카메라가 주인공을 따라다니므로 전투는 늘 가운데에 있어 문제되지 않는다.

- [ ] **Step 1: 지금 값을 눈으로 확인한다**

```bash
sed -n '20,31p' flutter/lib/ui/stage/battle_stage_game.dart
grep -n "portraitUp\|setPreferredOrientations" flutter/lib/main.dart
grep -rn "physicalSize" flutter/test/
```

기대: 무대 `360×480`, 뷰 `300×400`, `main.dart`에 `DeviceOrientation.portraitUp`, 테스트 넷이 세로 크기(`600×1600`, `600×2400`, `390×844`, `1200×240`, `360×270`)를 쓴다.

`art_gallery_test.dart`의 `1200×240`과 `360×270`은 **스프라이트·배경 캡처용이라 화면이 아니다.** 건드리지 마라. 고칠 것은 `:101`의 `390×844` 하나다.

- [ ] **Step 2: 방향을 가로로 바꾼다**

```bash
python3 - <<'EOF'
import pathlib
p = pathlib.Path('flutter/lib/main.dart')
s = p.read_text()
old = """  // 세로 고정 (GAME_DESIGN 1장)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);"""
new = """  // 가로 고정 (GAME_DESIGN 1장, 2026-09-05 변경).
  // 레퍼런스 화면 구조가 전부 가로 폭에 기댄다 — 좌측 세로 탭 + 우측 그리드, 왼쪽 대상 + 오른쪽 목록.
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);"""
assert old in s, "방향 고정 줄을 못 찾았다"
p.write_text(s.replace(old, new))
print("ok")
EOF
```

- [ ] **Step 3: 무대·카메라 상수를 바꾼다**

```bash
python3 - <<'EOF'
import pathlib
p = pathlib.Path('flutter/lib/ui/stage/battle_stage_game.dart')
s = p.read_text()
old = """/// 세로 화면을 채우도록 3:4로 잡는다. 배경 그림(360×270)은 지평선 아래를 세로로 반복해 채운다.
const stageHeight = 480.0;"""
new = """/// 가로 화면을 채우도록 약 16:9로 잡는다(2026-09-05 세로→가로 전환).
/// 카메라가 cover라 기기 비율에 따라 잘리는 방향이 다르다 — 넓은 폰은 위아래, 태블릿은 좌우.
/// 안전 영역은 가운데 269×162. 그 밖은 잘릴 수 있다.
const stageHeight = 202.0;"""
assert old in s, "stageHeight 줄을 못 찾았다"
s = s.replace(old, new)

old2 = """const viewWidth = 300.0;
const viewHeight = 400.0;"""
new2 = """const viewWidth = 300.0;
const viewHeight = 168.0;"""
assert old2 in s, "viewHeight 줄을 못 찾았다"
p.write_text(s.replace(old2, new2))
print("ok")
EOF
```

`viewHeight`는 `stageHeight`와 같은 비율로 줄인다 — 지금 `400/480 = 0.833`이고 `202 × 0.833 ≈ 168`이다.

**이 두 상수는 Task 2에서 사라진다.** cover 카메라는 보이는 크기를 기기에서 계산하므로 고정값이 필요 없다. 그래도 Task 1에서 값을 맞춰 두는 이유는 **Task 1만 끝난 상태에서도 화면이 안 깨지고 돌아가야** 하기 때문이다.

- [ ] **Step 4: 테스트의 화면 크기를 가로로 바꾼다**

```bash
python3 - <<'EOF'
import pathlib
edits = [
    ('flutter/test/ui/game_screen_test.dart', 'const Size(600, 1600)', 'const Size(1600, 720)'),
    ('flutter/test/ui/codex_screen_test.dart', 'const Size(600, 2400)', 'const Size(1600, 720)'),
    ('flutter/test/ui/art_gallery_test.dart', 'const Size(390, 844)', 'const Size(844, 390)'),
]
for path, old, new in edits:
    p = pathlib.Path(path)
    s = p.read_text()
    assert old in s, f"{path}에서 {old}를 못 찾았다"
    n = s.count(old)
    p.write_text(s.replace(old, new))
    print(f"{path}: {n}곳 교체")
EOF
```

`1600×720`은 논리 픽셀이 아니라 **물리 픽셀**이다. `devicePixelRatio`가 테스트에서 보통 1이 아니므로 실제 논리 크기는 다를 수 있다 — 통과 여부로만 판단하고 크기를 미세 조정하지 마라.

- [ ] **Step 5: 테스트를 돌린다**

```bash
cd flutter && flutter test 2>&1 | tail -20
```

기대: **전부 통과.** 실패하면 실패 메시지를 그대로 리포트에 적고, **테스트가 세로를 전제해서 깨진 것인지 코드가 깨진 것인지 구분해서** 보고하라. 세로 전제 때문이면 그 테스트의 크기를 고치는 것이 맞다. 코드가 깨졌으면 BLOCKED로 보고하라.

- [ ] **Step 6: 커밋**

```bash
git add flutter/lib/main.dart flutter/lib/ui/stage/battle_stage_game.dart flutter/test/
git commit -m "feat(flutter): 가로 고정 — 무대를 360×202로

레퍼런스 화면 구조가 전부 가로 폭에 기댄다. 좌측 세로 탭 + 우측
그리드, 왼쪽 대상 + 오른쪽 목록이 세로에서는 안 들어간다.

무대 폭 360은 유지한다. 스프라이트 크기가 이 폭을 전제로 정해졌다.

약 16:9로 잡았다. 요즘 폰 가로가 16:9~20:9 사이의 한가운데다.
카메라는 다음 커밋에서 cover로 바꾼다. 이 커밋만으로도 화면은 돈다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 카메라를 cover로

**Files:**
- Modify: `flutter/lib/ui/stage/battle_stage_game.dart` (카메라 생성, `_follow`의 줌·클램프, 상수 `viewWidth`/`viewHeight` 제거)

**Interfaces:**
- Consumes: Task 1의 `stageWidth = 360`, `stageHeight = 202`
- Produces: 검은 띠 없는 화면. Task 3의 배경이 이 위에 그려진다

**문제**: `CameraComponent.withFixedResolution`은 **레터박스**다 — 정해진 해상도를 화면에 맞춰 넣고 남는 곳에 검은 띠를 둔다. 레퍼런스는 화면을 꽉 채운다. 띠가 있으면 싸구려로 보인다.

**cover로 바꿀 때 생기는 진짜 문제**: 지금 `_follow`는 보스일 때 `zoom × 0.86`으로 **물러난다**(`battle_stage_game.dart` 154행 부근). cover 상태에서 더 물러나면 **무대 밖 빈 곳이 보인다.** 무대 폭 360은 아트 규격이라 늘릴 수 없다.

**해결 — 방향을 뒤집는다.** 평소에 살짝 당겨 두고(`×1.16`), 보스일 때 cover 배율로 **돌아온다**. 체감은 똑같이 "보스에서 물러난다"인데 무대 밖으로는 절대 안 나간다.

- [ ] **Step 1: 지금 카메라 코드를 확인한다**

```bash
grep -n "withFixedResolution\|viewWidth\|viewHeight\|wantedZoom\|halfW\|halfH" flutter/lib/ui/stage/battle_stage_game.dart
```

기대: `super(camera: CameraComponent.withFixedResolution(width: viewWidth, height: viewHeight))`, `wantedZoom = (isBoss) ? 0.86 : 1.0`, `halfW/halfH`가 `viewWidth/viewHeight`를 쓴다.

- [ ] **Step 2: 카메라를 기본 뷰포트로 바꾸고 cover 배율을 계산한다**

`CameraComponent`의 기본 뷰포트가 `MaxViewport`(화면 전체, 자르지 않음)다. 배율은 **화면을 덮는 최소 배율**이다.

`fix_camera.py`로 저장해서 실행하라 — heredoc 안에 삼중 따옴표를 겹치면 파이썬이 깨진다.

```python
# fix_camera.py
import pathlib
p = pathlib.Path('flutter/lib/ui/stage/battle_stage_game.dart')
s = p.read_text()

# ① 고정 해상도 뷰포트를 버린다
old = 'super(camera: CameraComponent.withFixedResolution(width: viewWidth, height: viewHeight));'
new = 'super(camera: CameraComponent());'
assert old in s, '카메라 생성부를 못 찾았다'
s = s.replace(old, new)

# ② 상수 둘을 지우고 cover 배율 설명으로 바꾼다
old2 = """/// 카메라가 한 번에 보여 주는 크기. 무대보다 작아야 카메라가 움직일 자리가 생긴다.
///
/// 무대와 같은 크기면 카메라가 붙박이가 되어 화면이 죽는다. 조금 좁게 잘라 두면
/// 주인공과 몬스터 사이를 따라다니며 전투가 살아 있는 것처럼 보인다.
const viewWidth = 300.0;
const viewHeight = 168.0;"""
new2 = """/// 평소에 얼마나 당겨 두는가. cover 배율의 몇 배인지다.
///
/// 1.0이면 화면이 무대를 딱 덮어 카메라가 움직일 자리가 없다. 조금 당겨 두면
/// 주인공과 몬스터 사이를 따라다니며 전투가 살아 있는 것처럼 보인다.
/// 보스일 때는 1.0으로 돌아가 물러난다 — cover보다 더 물러나면 무대 밖이 보인다.
const normalZoomFactor = 1.16;"""
assert old2 in s, 'view 상수 블록을 못 찾았다'
s = s.replace(old2, new2)

# ③ 줌과 클램프를 cover 기준으로
old3 = """    // 보스는 크다. 조금 물러나 전신이 들어오게 한다. 자르는 폭도 이 확대율을 따라간다.
    final wantedZoom = (_last?.isBoss ?? false) ? 0.86 : 1.0;"""
new3 = """    // 화면을 덮는 최소 배율. 기기 비율이 바뀌면 같이 바뀐다.
    final vp = camera.viewport.size;
    final cover = math.max(vp.x / stageWidth, vp.y / stageHeight);
    // 보스는 크다. cover로 돌아가 전신이 들어오게 한다.
    // cover보다 더 물러나면 무대 밖 빈 곳이 보이므로 이 아래로는 안 내려간다.
    final wantedZoom = cover * ((_last?.isBoss ?? false) ? 1.0 : normalZoomFactor);"""
assert old3 in s, '줌 계산부를 못 찾았다'
s = s.replace(old3, new3)

old4 = """    final halfW = math.min(stageWidth / 2, viewWidth / 2 / nextZoom);
    final halfH = math.min(stageHeight / 2, viewHeight / 2 / nextZoom);"""
new4 = """    final halfW = math.min(stageWidth / 2, vp.x / 2 / nextZoom);
    final halfH = math.min(stageHeight / 2, vp.y / 2 / nextZoom);"""
assert old4 in s, '클램프부를 못 찾았다'
s = s.replace(old4, new4)

p.write_text(s)
print('ok')
```

- [ ] **Step 3: 카메라 초기 위치가 여전히 맞는지 확인한다**

```bash
grep -n "viewfinder.anchor\|viewfinder.position\|viewfinder.zoom" flutter/lib/ui/stage/battle_stage_game.dart
```

기대: `onLoad`에서 `anchor = Anchor.center`, `position = Vector2(stageWidth / 2, stageHeight / 2)`. **이건 안 바꾼다** — 무대 한가운데를 보는 것은 그대로 맞다.

다만 **초기 `zoom`이 1.0이면 첫 프레임이 아주 작게 나온다.** `_follow`가 지수 감쇠로 따라오므로 몇 프레임 뒤엔 맞지만, 첫 프레임이 튄다. `onLoad`에서 초기 줌을 cover로 한 번 맞춰 준다.

```python
# fix_camera_init.py
import pathlib
p = pathlib.Path('flutter/lib/ui/stage/battle_stage_game.dart')
s = p.read_text()
old = "    camera.viewfinder.position = Vector2(stageWidth / 2, stageHeight / 2);"
new = """    camera.viewfinder.position = Vector2(stageWidth / 2, stageHeight / 2);
    // 첫 프레임이 튀지 않게 cover 배율로 시작한다. 이후는 _follow가 이어받는다.
    final vp0 = camera.viewport.size;
    camera.viewfinder.zoom =
        math.max(vp0.x / stageWidth, vp0.y / stageHeight) * normalZoomFactor;"""
assert old in s, '초기 위치 줄을 못 찾았다'
p.write_text(s.replace(old, new))
print('ok')
```

- [ ] **Step 4: `viewWidth`/`viewHeight`가 다른 곳에 안 남았는지 확인한다**

```bash
grep -rn "viewWidth\|viewHeight" flutter/lib flutter/test
```

기대: **하나도 안 잡힌다.** 잡히면 그 파일도 고쳐야 한다 — 어디서 잡혔는지 리포트에 적어라.

- [ ] **Step 5: 테스트를 돌린다**

```bash
cd flutter && flutter test 2>&1 | tail -12
```

기대: 전부 통과. `camera.viewport.size`가 테스트 환경에서 0이 될 수 있다 — 그러면 `cover`가 0이 되고 배율이 0이 되어 화면이 안 보인다. **`vp.x`나 `vp.y`가 0이면 이전 배율을 그대로 두도록 방어해야 하는지** 테스트 결과로 판단하라. 통과하면 방어를 넣지 마라(YAGNI). 깨지면 그때 넣고 그 사실을 리포트에 적어라.

- [ ] **Step 6: 커밋**

```bash
git add flutter/lib/ui/stage/battle_stage_game.dart
git commit -m "feat(flutter): 카메라를 cover로 — 검은 띠를 없앤다

withFixedResolution은 레터박스라 기기 비율이 다르면 검은 띠가 생긴다.
레퍼런스는 화면을 꽉 채운다.

보스 줌아웃의 방향을 뒤집었다. cover 상태에서 더 물러나면 무대 밖
빈 곳이 보이는데 무대 폭 360은 아트 규격이라 못 늘린다. 그래서
평소에 1.16배 당겨 두고 보스일 때 cover로 돌아온다. 체감은 같고
무대 밖으로는 안 나간다.

viewWidth/viewHeight 상수는 지웠다. 보이는 크기를 기기에서 계산한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 3: 배경 지평선을 가로에 맞게

**Files:**
- Modify: `flutter/lib/ui/stage/battle_stage_game.dart` (`_Background.render`)

**Interfaces:**
- Consumes: Task 1의 `stageHeight = 202`, Task 2의 cover 카메라
- Produces: 가로 무대를 채우는 배경. 판정은 사용자가 캡처를 보고 한다

**문제**: 지금 코드는 `far.png`(360×110, 하늘)를 그대로 위에 그리고 `ground.png`(360×160)를 지평선 110 아래로 **늘려서** 채운다(`stageHeight - horizon = 370`, 2.3배). 무대가 202가 되면 지평선 아래가 92px뿐이라 늘림은 사라지지만, **하늘이 110으로 화면의 54%**가 된다. 가로 화면에서 하늘이 절반 넘게 차지하면 전투가 아래에 눌린다.

- [ ] **Step 1: 지금 그리기 코드를 확인한다**

```bash
grep -n "horizon" flutter/lib/ui/stage/battle_stage_game.dart
sed -n '/canvas.drawImage(far/,/^  }/p' flutter/lib/ui/stage/battle_stage_game.dart
```

기대: `horizon`이 상수로 있고(`_Background`의 `static const horizon = 110.0`), `far`를 `Offset.zero`에 그린 뒤 `ground`를 `Rect.fromLTWH(0, horizon, stageWidth, stageHeight - horizon)`로 늘려 그린다.

- [ ] **Step 2: 지평선을 무대 비율로 계산하게 바꾼다**

하늘을 화면의 **30%**로 잡는다. `202 × 0.3 ≈ 61`. `far.png`는 110이므로 **아래쪽 61px만 잘라 쓴다** — 위쪽(하늘 꼭대기)을 버린다. 픽셀아트라 크기를 줄이면 계단이 뭉개지므로 **자르되 늘리거나 줄이지 않는다.**

`ground.png`(160)는 지평선 아래 141px에 넣는다. 160 → 141은 **줄이는** 것이라 지금의 2.3배 늘림보다 훨씬 낫지만 여전히 비정수 배율이다. 그래서 **아래쪽 141px만 잘라 쓴다** — 지평선에 가까운 위쪽(먼 땅)을 버린다.

```bash
python3 - <<'EOF'
import pathlib
p = pathlib.Path('flutter/lib/ui/stage/battle_stage_game.dart')
s = p.read_text()

old = "  static const horizon = 110.0;"
new = """  /// 하늘이 차지하는 비율. 가로 화면에서 하늘이 절반을 넘으면 전투가 아래로 눌린다.
  static const skyRatio = 0.3;

  /// 지평선 y. 무대 높이에서 계산한다 — 무대 비율이 바뀌면 같이 움직인다.
  static double get horizon => (stageHeight * skyRatio).roundToDouble();"""
assert old in s, "horizon 상수를 못 찾았다"
s = s.replace(old, new)

old2 = """    canvas.drawImage(far, Offset.zero, _pixel);
    // 배경 그림(360×270)보다 무대가 길다. 지평선 아래를 세로로 늘려 채운다.
    // 이어붙이면 바위·버섯이 반복돼 티가 나므로 늘리는 쪽을 택했다.
    // 세로 배경 그림이 들어오면 이 늘림은 사라진다.
    canvas.drawImageRect(
      ground,
      Rect.fromLTWH(0, 0, ground.width.toDouble(), ground.height.toDouble()),
      Rect.fromLTWH(0, horizon, stageWidth, stageHeight - horizon),
      _pixel,
    );"""
new2 = """    // 가로 무대는 배경 그림(360×270)보다 낮다. 늘리지 않고 잘라 쓴다 —
    // 픽셀아트는 비정수 배율로 줄이면 계단이 뭉개진다.
    // 하늘은 아래쪽(지평선에 가까운 쪽)을 남기고 꼭대기를 버린다.
    final skyKeep = math.min(horizon, far.height.toDouble());
    canvas.drawImageRect(
      far,
      Rect.fromLTWH(0, far.height - skyKeep, far.width.toDouble(), skyKeep),
      Rect.fromLTWH(0, horizon - skyKeep, stageWidth, skyKeep),
      _pixel,
    );
    // 땅은 위쪽(먼 땅)을 버리고 아래쪽을 남긴다. 캐릭터가 서는 곳이 아래다.
    final groundNeed = stageHeight - horizon;
    final groundKeep = math.min(groundNeed, ground.height.toDouble());
    canvas.drawImageRect(
      ground,
      Rect.fromLTWH(0, ground.height - groundKeep, ground.width.toDouble(), groundKeep),
      Rect.fromLTWH(0, stageHeight - groundKeep, stageWidth, groundKeep),
      _pixel,
    );"""
assert old2 in s, "배경 그리기 블록을 못 찾았다"
p.write_text(s.replace(old2, new2))
print("ok")
EOF
```

**`horizon`은 두 곳에서 쓰인다** — `:424`(배경 에셋이 없는 지역의 그라데이션 경로에서 땅에 그늘을 깔 때)와 `:436`(그림 경로). 상수를 게터로 바꾸면 **두 곳이 한 번에 고쳐진다.** 그라데이션 경로는 따로 손댈 필요가 없다.

`math`는 파일 첫 줄에 `import 'dart:math' as math;`로 이미 들어와 있다(확인함). 더하지 마라.

- [ ] **Step 3: 하늘이 남는 경우를 확인한다**

`skyKeep = min(horizon, far.height)`이므로 하늘이 부족하면(`horizon > 110`) 위쪽에 빈 곳이 생긴다. 무대 202 · 비율 0.3이면 `horizon = 61`이라 문제없지만, 나중에 비율을 올리면 생길 수 있다.

```bash
grep -n "skyKeep\|groundKeep\|horizon" flutter/lib/ui/stage/battle_stage_game.dart
```

기대: `horizon`이 61(202×0.3)로 계산되고 `far.height`(110)보다 작다. 빈 곳이 안 생긴다. **`horizon > far.height`가 되면 위쪽이 비므로**, 그때는 하늘색으로 먼저 칠하거나 `far`를 세로로 늘려야 한다 — 지금은 안 일어나므로 **미리 만들지 마라**.

- [ ] **Step 4: 테스트를 돌린다**

```bash
cd flutter && flutter test 2>&1 | tail -8
```

기대: 전부 통과.

- [ ] **Step 5: 실제 화면을 캡처한다**

```bash
cd flutter && flutter test test/ui/art_gallery_test.dart 2>&1 | tail -3
ls -la build/*.png
```

기대: `build/app_screen.png` · `build/battle_stage.png`이 **가로 비율로** 새로 만들어진다. 파일 크기와 수정 시각을 리포트에 적어라.

- [ ] **Step 6: 커밋**

```bash
git add flutter/lib/ui/stage/battle_stage_game.dart
git commit -m "feat(flutter): 배경 지평선을 무대 비율로 — 늘리지 않고 잘라 쓴다

지평선을 110 고정에서 무대 높이의 30%로 바꿨다. 가로 무대(202)에서
하늘이 110이면 화면의 54%다. 전투가 아래로 눌린다.

늘리기를 버리고 자르기로 갔다. 픽셀아트는 비정수 배율로 줄이면
계단이 뭉개진다. 하늘은 꼭대기를, 땅은 먼 쪽을 버린다 — 캐릭터가
서는 곳은 아래다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: 문서를 사실에 맞춘다

**Files:**
- Modify: `GAME_DESIGN.md` 1장
- Modify: `docs/BACKLOG.md` D2
- Modify: `docs/superpowers/specs/2026-09-03-art-pipeline-design.md` (무대 규격)

**Interfaces:**
- Consumes: Task 1~3이 확정한 값 (`360×202`, 하늘 30%)
- Produces: 다음 사람이 읽을 정본

- [ ] **Step 1: 기획서 1장을 고친다**

```bash
grep -n "세로 고정" GAME_DESIGN.md
python3 - <<'EOF'
import pathlib
p = pathlib.Path('GAME_DESIGN.md')
s = p.read_text()
old = "| 화면 | 세로 고정 |"
new = "| 화면 | **가로 고정** (2026-09-05 변경). 레퍼런스 화면 구조가 전부 가로 폭에 기댄다 — 좌측 세로 탭 + 우측 그리드, 왼쪽 대상 + 오른쪽 목록. 잃는 것은 한 손 조작이다 |"
assert old in s, "화면 행을 못 찾았다"
p.write_text(s.replace(old, new))
print("ok")
EOF
```

- [ ] **Step 2: 백로그 D2를 고친다**

**삭제하지 마라.** 지역마다 배경 한 벌씩 10벌이 필요하다는 사실은 그대로다. 규격만 바뀐다.

```bash
python3 - <<'EOF'
import pathlib
p = pathlib.Path('docs/BACKLOG.md')
s = p.read_text()
old = """### D2. 세로 배경 10지역 · M
지금 배경은 360×270 가로 한 벌뿐이라 세로 화면에서 아래쪽을 늘려 메우고 있다.
360×480으로 지역마다 한 벌씩 필요하다."""
new = """### D2. 배경 10지역 · M
지금 배경은 숲 한 벌뿐이다(`far.png` 360×110 + `ground.png` 360×160). 지역마다 한 벌씩 필요하다.

2026-09-05 가로 전환으로 **규격이 바뀌었다.** 세로용 360×480은 필요 없다.
무대가 360×202이고 하늘 30%·땅 70%로 잘라 쓰므로, 하늘은 61px 이상 · 땅은 141px 이상이면 된다.
지금 파일은 그 조건을 넘으므로 **숲은 다시 안 그려도 된다.** 남은 것은 나머지 9지역이다."""
assert old in s, "D2 블록을 못 찾았다"
p.write_text(s.replace(old, new))
print("ok")
EOF
```

- [ ] **Step 3: 아트 파이프라인 스펙의 죽은 화면 표를 폐기 처리한다**

이 스펙의 **4절 "화면 레이아웃" 표는 가로 전환 이전부터 이미 틀려 있었다.** `헤더 48 / 무대 360×270 4:3 / 스킬 바 60 / 탭 내용 / 탭 바 48`은 **탭 바 시절 구조**인데, 지금은 탭이 아니라 전투 화면 + 팝업이다(백로그 A4 완료). `:135`의 `가상 해상도 360×270 고정 뷰포트`도 실제 코드(`360×480`)와 달랐다.

**다시 쓰지 마라. 폐기 표시를 하고 새 정본을 가리켜라** — 화면 레이아웃의 정본은 이제 `2026-09-05-screen-map-design.md`다.

치환 셋을 한 스크립트로 돌린다. 파이썬 스크립트를 파일로 저장해서 실행하라 — 삼중 따옴표가 겹쳐 heredoc이 깨진다.

```python
# fix_pipeline_spec.py
import pathlib
p = pathlib.Path('docs/superpowers/specs/2026-09-03-art-pipeline-design.md')
s = p.read_text()

pairs = [
  ('- 무대는 가로 **360 픽셀 단위**의 가상 해상도로 설계하고 기기 가로폭에 맞춰 통째로 확대한다. 375pt 기기에서 약 1.04배.',
   '- 무대는 가로 **360 픽셀 단위**의 가상 해상도로 설계하고 기기 가로폭에 맞춰 통째로 확대한다. 폭 360은 가로 전환 뒤에도 그대로다(2026-09-05). 높이는 `360×202`.'),

  ('- 가상 해상도 360×270 고정 뷰포트. 최근접 보간. 액터 위치 정수 반올림.',
   '- 최근접 보간. 액터 위치 정수 반올림. (해상도는 `360×202` — 2026-09-05 가로 전환. 여기 적혀 있던 `360×270`은 스파이크 당시 값이라 코드와 이미 달랐다.)'),

  ('## 4. 화면 레이아웃',
   '## 4. 화면 레이아웃 — **폐기 (2026-09-05)**\n\n> **이 절은 죽었다.** 아래 표는 탭 바 시절 구조이고, 지금은 탭이 아니라 전투 화면 하나 + 팝업이다(백로그 A4 완료).\n> 가로 전환 이전부터 코드와 어긋나 있었다. **화면 레이아웃의 정본은 `2026-09-05-screen-map-design.md`다.**\n> 아래는 어떤 결정이 어떻게 바뀌었는지 보려고 남긴 이력이다.'),
]
for old, new in pairs:
    assert old in s, old[:30]
    s = s.replace(old, new, 1)
p.write_text(s)
print('ok')
```

폭 360은 안 바뀌었으므로 **스프라이트 크기표(§1)는 건드리지 마라.**

- [ ] **Step 4: 문서끼리 안 어긋나는지 확인한다**

```bash
grep -rn "세로 고정\|portraitUp\|360×480\|3:4\|360×270 고정" GAME_DESIGN.md docs/ flutter/lib/
```

기대: **규격 값으로는 하나도 안 잡힌다.** 잡히는 것은 두 종류만 허용된다 — ① 변경 이력(`세로 고정 → 가로 고정` 같은 기록) ② 폐기 표시가 붙은 절(`art-pipeline-design.md` 4절). 그 외에 잡히면 옛 값이 남은 것이므로 고쳐라. **잡힌 줄을 하나씩 읽고 어느 쪽인지 리포트에 적어라.**

- [ ] **Step 5: 커밋**

```bash
git add GAME_DESIGN.md docs/
git commit -m "docs: 가로 전환을 정본에 반영 — D2는 삭제가 아니라 규격 변경

기획서 1장의 '세로 고정'에는 근거가 없었다. 가로로 바꾸고 이유와
잃는 것(한 손 조작)을 같이 적었다.

백로그 D2는 살려 뒀다. 세로용 360×480 규격은 필요 없어졌지만
지역마다 배경 한 벌씩 10벌이 필요하다는 사실은 그대로다.
숲은 지금 파일이 조건을 넘어 다시 안 그려도 된다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: 도메인 좌표를 새 무대에 맞춘다 (실행 중 추가)

**Files:**
- Modify: `flutter/lib/domain/field.dart` (상수 4개)
- Modify: `flutter/lib/ui/stage/battle_stage_game.dart:21-26` (`stageWidth`/`stageHeight`를 도메인에서 가져오게)

**Interfaces:**
- Consumes: Task 1의 `stageHeight = 202`, Task 3의 `horizon = 61`
- Produces: 캐릭터가 무대 안에 서 있는 상태. 전체 리뷰와 다음 계획(자리 재배치)이 이걸 전제한다

**왜 생긴 태스크인가**: Task 3 리뷰가 잡았다. `field.dart`가 `fieldHeight = 480`, `heroHomeY = 330`, `fieldTopY..fieldBottomY = 200..430`으로 **세로 무대 값**을 갖고 있다. 무대가 202가 됐으니 **주인공과 몬스터가 무대 아래에 있다** — 캡처에 캐릭터가 하나도 안 보이고, 카메라가 그들을 따라 바닥에 붙어 하늘이 4%만 보인다. 계획이 이 파일을 빠뜨렸다. 계획의 목표("안 깨지고 돌아간다")를 어기므로 이 계획 안에서 고친다.

**값의 근거**: 지평선 61. 땅은 `61..202`(141px). 액터는 발이 `y`에 닿는다(`Anchor.bottomCenter`). 주인공 56px, 보스 96px.

| 상수 | 옛 값 | 새 값 | 이유 |
|---|---|---|---|
| `fieldHeight` | 480 | **202** | 무대와 같아야 한다 |
| `fieldTopY` | 200 | **80** | 발이 지평선(61)보다 19px 아래. 머리(56 위)가 24 — 하늘에 안 걸린다 |
| `fieldBottomY` | 430 | **190** | 아래 여유 12px |
| `heroHomeY` | 330 | **140** | 땅 띠(80..190)의 가운데 |

`heroHomeX = 58`, `monsterSpawnX = 400`(오른쪽 밖), `separationRadius = 28`은 그대로 — 가로 폭이 안 바뀌었다. 세로 띠 110px에 몬스터 3~5마리를 28px 간격으로 퍼뜨리면 들어간다.

- [ ] **Step 1: 지금 값과 사용처를 확인한다**

```bash
sed -n '1,20p' flutter/lib/domain/field.dart
grep -rn "fieldHeight\|heroHomeY\|fieldTopY\|fieldBottomY" flutter/lib flutter/test | grep -v "lib/domain/field.dart" | wc -l
```

기대: 상수 4개가 옛 값이고, 사용처가 **전부 이름으로** 참조한다(숫자 330·430을 박은 곳이 없다). 그래서 상수만 바꾸면 도메인·UI·테스트가 다 따라온다.

- [ ] **Step 2: 상수를 바꾼다**

파일로 저장해서 실행한다.

```python
# fix_field.py
import pathlib
p = pathlib.Path('flutter/lib/domain/field.dart')
s = p.read_text()
pairs = [
    ('const fieldHeight = 480.0;', 'const fieldHeight = 202.0;'),
    ('const heroHomeY = 330.0;', 'const heroHomeY = 140.0;'),
    ('const fieldTopY = 200.0;', 'const fieldTopY = 80.0;'),
    ('const fieldBottomY = 430.0;', 'const fieldBottomY = 190.0;'),
    ('/// 몬스터가 설 수 있는 세로 범위. 3/4 시점이라 위아래로 퍼져야 깊이가 보인다.',
     '/// 몬스터가 설 수 있는 세로 범위. 3/4 시점이라 위아래로 퍼져야 깊이가 보인다.\n'
     '/// 가로 무대(202)의 땅 띠(지평선 61 아래)에 들어간다. 발이 y에 닿으므로 위쪽은 머리가 하늘에 안 걸리게 잡는다.'),
]
for old, new in pairs:
    assert old in s, old
    s = s.replace(old, new, 1)
p.write_text(s)
print('ok')
```

- [ ] **Step 3: UI 무대 크기가 도메인에서 값을 가져오게 묶는다**

이 어긋남이 생긴 이유는 `stageHeight`(UI)와 `fieldHeight`(도메인)가 **따로 정의돼** 있어서다. Task 1이 한쪽만 바꿨다. 한쪽이 다른 쪽을 가리키게 하면 다시는 안 갈라진다. **UI가 도메인을 본다** — 도메인은 UI를 몰라야 한다.

```python
# fix_stage_consts.py
import pathlib
p = pathlib.Path('flutter/lib/ui/stage/battle_stage_game.dart')
s = p.read_text()
old = 'const stageWidth = 360.0;'
new = 'const stageWidth = fieldWidth;'
assert old in s, 'stageWidth'
s = s.replace(old, new, 1)
old = 'const stageHeight = 202.0;'
new = ('const stageHeight = fieldHeight;\n'
       '// 무대 크기는 도메인(field.dart)이 정한다. 여기서 따로 숫자를 두면 둘이 갈라진다 —\n'
       '// 2026-09-05 가로 전환 때 실제로 갈라져 캐릭터가 무대 아래로 나갔다.')
assert old in s, 'stageHeight'
s = s.replace(old, new, 1)
p.write_text(s)
print('ok')
```

`field.dart`는 이미 import돼 있다(10행). 더하지 마라.

- [ ] **Step 4: 테스트를 돌린다**

```bash
cd flutter && flutter test 2>&1 | tail -12
```

기대: 전부 통과. 테스트가 상수를 이름으로 쓰므로 값이 바뀌어도 따라온다. 깨지면 **어느 테스트가 어떤 숫자를 박아 뒀는지** 리포트에 적고, 그 테스트만 상수 참조로 고쳐라. 도메인 로직이 깨졌으면 BLOCKED.

- [ ] **Step 5: 캡처를 다시 만들고 캐릭터가 보이는지 확인한다**

```bash
cd flutter && flutter test test/ui/art_gallery_test.dart 2>&1 | tail -3
ls -la build/*.png
```

기대: `app_screen.png`과 `battle_stage.png`에 **주인공이 보인다.** 파일 크기·시각을 리포트에 적어라. 리뷰어가 열어 본다.

- [ ] **Step 6: 커밋**

```bash
git add flutter/lib/domain/field.dart flutter/lib/ui/stage/battle_stage_game.dart
git commit -m "fix(flutter): 도메인 좌표를 가로 무대에 맞춘다 — 캐릭터가 무대 아래에 있었다

field.dart가 세로 무대(480) 값을 갖고 있었다. 무대가 202가 되자
주인공(y=330)과 몬스터(200..430)가 화면 아래로 나갔다. 카메라가 그들을
따라 바닥에 붙어 하늘도 4%만 보였다.

UI의 stageWidth/stageHeight가 도메인의 fieldWidth/fieldHeight를
가리키게 묶었다. 따로 두면 또 갈라진다.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## 이 계획이 하지 않는 것

- **자리 재배치.** `game_screen.dart`의 `Positioned(left: 6, top: 84)` 같은 세로 전제 좌표는 **그대로 둔다.** 가로에서 어긋나 보이겠지만 안 깨진다. 일곱 자리로 옮기는 것은 다음 계획이다
- **메뉴 그리드 신설** — 다음 계획
- **팝업 좌측 초상 열** — 그다음 계획
- **배경 9지역 그리기** — 크레딧이 필요하다

## 알려진 위험

| 위험 | 어디서 터지나 | 대응 |
|---|---|---|
| 테스트가 세로를 전제해 깨진다 | Task 1 Step 5 | 크기만 고쳐서 통과하면 정상. 코드가 깨졌으면 BLOCKED |
| 하늘 30%가 너무 좁아 보인다 | Task 2 Step 5 캡처 | `skyRatio` 하나만 고치면 된다. 상수로 뺀 이유가 이것이다 |
| 테스트에서 `camera.viewport.size`가 0이다 | Task 2 Step 5 | 배율이 0이 되어 화면이 안 보인다. 테스트가 통과하면 방어를 넣지 마라 |
| 기기 비율에 따라 무대 가장자리가 잘린다 | 실기기에서 | cover의 대가다. 안전 영역은 가운데 `269×162`. 카메라가 주인공을 따라다니므로 전투는 늘 가운데에 있다 |
| `game_screen`의 세로 좌표가 화면 밖으로 나간다 | Task 1 Step 5 | 안 깨지면 통과. 다음 계획에서 옮긴다 |
