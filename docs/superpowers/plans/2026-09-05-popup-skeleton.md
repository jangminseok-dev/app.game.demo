# 팝업 공통 골격 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 스펙 4절의 여덟 규칙을 `GamePopup` 한 곳에 넣어, 앞으로 만드는 모든 팝업이 같은 골격을 공짜로 쓰게 한다.

**Architecture:** 골격은 전부 `lib/ui/hud/` 안에 산다. `GamePopup`이 제목 리본·닫기·폭·하단 여백을 책임지고, 새 위젯 셋이 나머지를 나눠 갖는다 — `PortraitTile`(초상 한 칸), `PopupTwoPane`/`PopupPane`(2단과 단별 일괄 단추), `showTargetPopup`(초상 열이 붙는 대상형 팝업). 패널들(`EquipmentPanel` 등)은 자기 내용만 그리고 골격은 안 그린다.

**Tech Stack:** Flutter 3.x · Riverpod · 기존 `pixel_ui.dart`(`PixelPanel`·`PixelText`·`PixelPalette`)·`pixel_icons.dart`(`PixelIcon`·`PixelIconView`)

**Spec:** `docs/superpowers/specs/2026-09-05-screen-map-design.md` (4절 "팝업 공통 골격")

## Global Constraints

- **화면은 가로 고정이다.** 세로를 위한 분기를 만들지 마라 (스펙 8절).
- **레퍼런스 게임의 이름·고유명을 코드·UI·자산 이름에 절대 넣지 마라.** 화풍과 구조만 가져온다.
- **`lib/domain/**` 과 `lib/app/**` 은 한 줄도 건드리지 않는다.** 이 계획은 표현 계층만 바꾼다. 게임 규칙이 바뀌어야 할 것 같으면 그건 이 계획의 일이 아니다 — BLOCKED로 보고하라.
- **새 기능을 넣지 마라.** 잠긴 자리(소환·상점·전용무기·동료·광고)는 계속 잠겨 있어야 한다.
- 주석·커밋 메시지·UI 문구는 **한국어**. 주변 코드의 말투(단정형, 짧은 문장)를 따른다.
- 각 태스크 끝에서 `cd flutter && flutter analyze` 가 **0건**(info 포함), `flutter test` 가 **전부 통과**여야 한다. 시작 기준은 **248개 통과 · analyze 0건**이다.
- 커밋 메시지 끝에 두 줄을 붙인다:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th
  ```

---

## 파일 구조

| 파일 | 책임 | 이 계획에서 |
|---|---|---|
| `flutter/lib/ui/hud/hud_metrics.dart` | 하단 HUD가 먹는 높이 상수 두 개 | **신규** — 팝업과 무대 글자가 같은 숫자를 본다 |
| `flutter/lib/ui/hud/game_popup.dart` | 팝업 한 장의 골격(제목 리본·닫기·폭·높이·초상 열 자리) | 폭 유동화, 리본에 아이콘·`?`, 닫기 원형, 하단 여백 |
| `flutter/lib/ui/hud/portrait_tile.dart` | 초상 한 칸과 대상 열거형 | **신규** — HUD 줄과 팝업 열이 같은 칸을 쓴다 |
| `flutter/lib/ui/hud/target_popup.dart` | 좌측 초상 열이 붙는 대상형 팝업 | **신규** — 초상을 누르면 내용만 바뀐다 |
| `flutter/lib/ui/hud/popup_two_pane.dart` | 본문 2단과 단별 일괄 단추·경고 | **신규** |
| `flutter/lib/ui/party_row.dart` | 우하단 초상 줄(AUTO + 초상 셋) | `PortraitTile` 사용, 라우팅을 `onSelect`로 밖에서 주입 |
| `flutter/lib/ui/equipment_panel.dart` | 장비 화면의 내용 | 손으로 짠 2단을 `PopupTwoPane`으로 교체 |
| `flutter/lib/ui/hud/reward_popup.dart` | 획득 연출 | 아이콘 한 자리 추가 |
| `flutter/lib/ui/battle_area.dart` | 무대 위 글자 세 줄 | `bottom` 을 상수에서 가져오게 |
| `flutter/lib/ui/game_screen.dart` | 화면 여덟 자리 | 팝업 호출부에 아이콘·도움말, 초상 줄에 `onSelect` |
| `flutter/lib/ui/hud/menu_grid.dart` | ≡ 가 여는 14칸 | `_open` 이 아이콘·도움말을 넘기게 |
| `flutter/test/ui/game_screen_test.dart` | 화면 위젯 테스트 | 태스크마다 추가 |

**왜 `hud/` 아래인가**: `pixel_ui.dart`는 색과 글자 같은 원자 부품이고, `hud/`의 나머지는 그 부품으로 만든 게임 UI다. 팝업 골격은 후자다.

---

### Task 1: 팝업 골격 — 폭·제목 리본·닫기·하단 여백

스펙 4.1(제목 리본 = 아이콘 + 이름 + ? 도움말), 4.2(닫기 ✕ 우상단 빨간 **원**), 4.6(팝업이 떠도 하단 바와 우하단 스킬칸이 보인다)을 한 번에 넣는다. 폭 460 고정도 여기서 푼다.

**Files:**
- Create: `flutter/lib/ui/hud/hud_metrics.dart`
- Modify: `flutter/lib/ui/hud/game_popup.dart` (`GamePopup`과 `showGamePopup`)
- Modify: `flutter/lib/ui/battle_area.dart` (`MonsterLine`의 `bottom`)
- Modify: `flutter/lib/ui/game_screen.dart`, `flutter/lib/ui/hud/menu_grid.dart`, `flutter/lib/ui/party_row.dart`, `flutter/lib/ui/equipment_panel.dart` (호출부에 `icon:`·`help:`)
- Test: `flutter/test/ui/game_screen_test.dart`

**Interfaces:**
- Produces:
  - `const bottomBarHeight = 69.0;` · `const hudBottomInset = 118.0;` (`hud_metrics.dart`)
  - `GamePopup({required String title, required PixelIcon icon, required Widget child, String? help, double heightFactor = 0.72, Widget? leading})`
  - `Future<void> showGamePopup(BuildContext context, {required String title, required PixelIcon icon, required Widget child, String? help, double heightFactor = 0.72, Widget? leading})`
  - 본문 패널에 `const Key('popup-body')` — 테스트가 팝업 본체의 사각형을 잰다
- Task 2가 `leading:` 에 초상 열을 꽂는다. Task 3이 `child:` 에 2단을 꽂는다.

**왜 상수가 두 개인가**: 하단 중앙 5칸(69px)보다 우하단 초상 줄 + 스킬칸(118px)이 더 높다. 무대 위 몬스터 글자는 화면 **가운데** 아래에 있으니 69만 피하면 되고, 팝업은 가운데에 뜨지만 오른쪽 열까지 안 덮으려면 118을 피해야 한다. 두 값을 한 파일에 두고 각자 필요한 것을 가져간다.

**측정 근거** (2026-09-05 전체 리뷰 실측):
- `bottomBarHeight` = `bottom 6` + 큰 단추 패널 54(테두리 2 + 여백 11 + 아이콘 28 + 여백 11 + 테두리 2) + 간격 2 + 라벨 7 = **69**
- `hudBottomInset` = `bottom 6` + 초상 줄 50(칸 38 + 간격 2 + 라벨 10) + 간격 6 + `SkillBar.height` 56 = **118**

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`flutter/test/ui/game_screen_test.dart` 맨 끝(마지막 `}` 앞)에 넣는다. 파일 위쪽 import에 다음을 더한다 — 이미 있으면 더하지 마라:

```dart
import 'package:app_game_demo/ui/hud/game_popup.dart';
import 'package:app_game_demo/ui/hud/hud_metrics.dart';
import 'package:app_game_demo/ui/hud/pixel_icons.dart';
```

(패키지 이름은 `flutter/pubspec.yaml`의 `name:` 을 그대로 쓴다. 기존 테스트 파일의 import 줄을 보고 맞춰라.)

```dart
  testWidgets('팝업이 하단 HUD 자리를 비운다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('장비').first);
    await tester.pumpAndSettle();

    final body = tester.getRect(find.byKey(const Key('popup-body')));
    expect(body.bottom, lessThanOrEqualTo(720 - hudBottomInset),
        reason: '팝업 아래로 하단 바와 우하단 스킬칸 자리가 남아야 한다 (스펙 4.6)');
  });

  testWidgets('좁은 화면에서도 팝업이 화면 안에 들어간다', (tester) async {
    tester.view.physicalSize = const Size(440, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 화면 전체가 아니라 팝업 하나만 띄운다 — 좁은 폭에서 HUD가 겹치는 것은 별개 문제(백로그 D4-2)다.
    await tester.pumpWidget(const MaterialApp(
      home: GamePopup(title: '장비', icon: PixelIcon.shield, child: SizedBox()),
    ));

    final body = tester.getRect(find.byKey(const Key('popup-body')));
    expect(body.left, greaterThanOrEqualTo(0));
    expect(body.right, lessThanOrEqualTo(440));
  });

  testWidgets('제목 리본에 아이콘과 도움말이 있고 도움말이 열린다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('장비').first);
    await tester.pumpAndSettle();
    expect(find.text('?'), findsWidgets, reason: '도움말 단추 (스펙 4.1)');

    await tester.tap(find.text('?').first);
    await tester.pumpAndSettle();
    expect(find.text('장비 도움말'), findsWidgets, reason: '도움말 창이 열렸다');
    expect(find.textContaining('가방을 눌러'), findsWidgets, reason: '장비 도움말 문구');
  });
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/ui/game_screen_test.dart 2>&1 | tail -20
```

기대: 컴파일 실패(`hud_metrics.dart` 없음, `GamePopup`에 `icon` 인자 없음). 컴파일이 되고 테스트만 실패해도 좋다. **통과하면 안 된다** — 통과하면 테스트가 아무것도 안 재는 것이니 멈추고 보고하라.

- [ ] **Step 3: 지표 상수 파일을 만든다**

`flutter/lib/ui/hud/hud_metrics.dart`:

```dart
// 하단 HUD가 먹는 높이. 팝업과 무대 글자가 이 값을 보고 자리를 비운다.
//
// 두 값이 다른 이유: 하단 중앙 5칸보다 우하단 초상 줄 + 스킬칸이 더 높다.
// 각자 재면 갈라진다 — 2026-09-05 전체 리뷰가 실제로 1px 간격을 잡아냈다.

/// 하단 중앙 5칸의 높이. bottom 6 + 큰 단추 54 + 간격 2 + 라벨 7.
const bottomBarHeight = 69.0;

/// 우하단 초상 줄 + 스킬칸의 높이. bottom 6 + 초상 50 + 간격 6 + 스킬바 56.
/// 팝업은 이만큼 아래를 비운다(스펙 4.6).
const hudBottomInset = 118.0;
```

- [ ] **Step 4: `GamePopup`을 다시 쓴다**

`flutter/lib/ui/hud/game_popup.dart`의 `GamePopup` 클래스와 `showGamePopup` 함수를 아래로 **통째로 교체**한다. 같은 파일의 `HudButton`은 손대지 마라.

파일 맨 위 import에 두 줄을 더한다:

```dart
import 'dart:math' as math;

import 'hud_metrics.dart';
```

교체할 내용:

```dart
/// 인게임 팝업 한 장. 전투 화면 위에 겹쳐 뜬다.
///
/// 레퍼런스처럼 기능마다 화면을 갈아 끼우지 않고 전투 위에 창을 띄운다.
/// 전투가 계속 돌아가는 것이 보여야 방치형의 "계속 크고 있다"는 감각이 끊기지 않는다.
///
/// 골격은 스펙 4절이다. 새 팝업은 예외 없이 이 위젯을 쓴다 —
/// 제목 리본은 좌상단, 닫기는 우상단 빨간 원, 하단 HUD는 안 덮는다.
class GamePopup extends StatelessWidget {
  const GamePopup({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.help,
    this.heightFactor = 0.72,
    this.leading,
  });

  final String title;

  /// 제목 리본 왼쪽 그림.
  final PixelIcon icon;

  final Widget child;

  /// `?` 를 눌렀을 때 나오는 설명. 없으면 `?` 를 안 그린다.
  final String? help;

  /// 화면 높이 대비 팝업 높이. 하단 HUD 자리를 뺀 나머지를 넘지 못한다.
  final double heightFactor;

  /// 팝업 **밖** 왼쪽에 붙는 것. 초상 열이 여기 들어간다(스펙 4.3).
  final Widget? leading;

  /// 초상 칸 폭 + 사이 간격. leading이 있을 때 본체 폭에서 뺀다.
  static const _leadingWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // 아래를 hudBottomInset 만큼 비운다 — 하단 바와 우하단 스킬칸이 계속 보인다(스펙 4.6).
        padding: const EdgeInsets.fromLTRB(10, 6, 10, hudBottomInset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(
              460.0,
              constraints.maxWidth - (leading == null ? 0.0 : _leadingWidth),
            );
            final height = math.min(
              MediaQuery.sizeOf(context).height * heightFactor,
              constraints.maxHeight,
            );
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 6),
                  ],
                  SizedBox(width: width, height: height, child: _body(context)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 제목 리본과 닫기 (스펙 4.1·4.2)
        Row(
          children: [
            PixelPanel(
              color: PixelPalette.goldDark,
              padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelIconView(icon, size: 16),
                  const SizedBox(width: 6),
                  PixelText(title, size: 14),
                ],
              ),
            ),
            if (help != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showHelp(context),
                child: const _RoundChip(color: PixelPalette.panelLight, label: '?'),
              ),
            ],
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const _RoundChip(color: Color(0xFF8C2F2F), label: 'X'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: PixelPanel(
            key: const Key('popup-body'),
            padding: const EdgeInsets.all(4),
            child: ClipRect(child: child),
          ),
        ),
      ],
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => Center(
        child: PixelPanel(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText('$title 도움말', size: 12, color: PixelPalette.gold),
                const SizedBox(height: 8),
                PixelText(help!, size: 11, color: PixelPalette.textDim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 둥근 칩 — 닫기 ✕ 와 도움말 ? (스펙 4.1·4.2). 사각 패널과 달리 원이라 눈에 먼저 띈다.
class _RoundChip extends StatelessWidget {
  const _RoundChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: PixelPalette.ink, width: 2),
      ),
      child: Center(child: PixelText(label, size: 13)),
    );
  }
}

/// 전투 위에 팝업을 띄운다. 바깥을 누르면 닫힌다.
Future<void> showGamePopup(
  BuildContext context, {
  required String title,
  required PixelIcon icon,
  required Widget child,
  String? help,
  double heightFactor = 0.72,
  Widget? leading,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => GamePopup(
      title: title,
      icon: icon,
      help: help,
      heightFactor: heightFactor,
      leading: leading,
      child: child,
    ),
  );
}
```

- [ ] **Step 5: 무대 글자가 상수를 보게 한다**

`flutter/lib/ui/battle_area.dart`에서 `MonsterLine`을 감싼 `Positioned`의 `bottom: 84` 를 바꾼다. 파일 위 import에 `import 'hud/hud_metrics.dart';` 를 더한다(기존 import 줄들과 알파벳 순서를 맞춰라).

```dart
        Positioned(
          // 하단 5칸 위 15px. textScaler·글꼴 메트릭으로 라벨이 자라도 겹치지 않게.
          left: 0, right: 0, bottom: bottomBarHeight + 15,
```

값은 그대로 84다. 숫자를 한 곳에서 관리하려는 것이지 위치를 옮기려는 것이 아니다.

- [ ] **Step 6: 호출부 전부에 아이콘과 도움말을 넣는다**

```bash
cd flutter && grep -rn "showGamePopup(" lib
```

15곳이 나온다(정의 1곳 제외 14곳). 표대로 인자를 더한다. **도움말 문구는 아래 것을 그대로 쓴다** — 각 문구는 그 화면이 실제로 하는 일을 검증하고 쓴 것이다. 문구가 화면과 안 맞으면 문구를 고치고 리포트에 적어라.

| 파일 · 제목 | `icon:` | `help:` |
|---|---|---|
| `game_screen.dart` `_showGrowthHint` (제목 두 가지) | `PixelIcon.growth` | 없음 |
| `game_screen.dart` `_showOfflineReward` '오프라인 보상' | `PixelIcon.growth` | 없음 |
| `game_screen.dart` · `menu_grid.dart` '성장' | `PixelIcon.growth` | `'골드로 능력치를 올린다. 층이 오르면 살 것이 는다.'` |
| `game_screen.dart` · `party_row.dart` '장비' | `PixelIcon.shield` | `'왼쪽은 입은 것, 오른쪽은 가방. 가방을 눌러 비교한다.'` |
| `game_screen.dart` '스킬' (`_showGrowthHint` 안) | `PixelIcon.spark` | `'스킬을 칸에 넣는다. AUTO면 알아서 나간다.'` |
| `game_screen.dart` · `party_row.dart` '펫' | `PixelIcon.egg` | `'알을 부화하고 용을 탐험 보낸다. 둘 다 시간이 지나야 끝난다.'` |
| `game_screen.dart` · `menu_grid.dart` '출석부' | `PixelIcon.check` | `'하루 한 번 받는다. 빠져도 다음 칸부터 이어진다.'` |
| `game_screen.dart` · `menu_grid.dart` '오늘 과제' | `PixelIcon.calendar` | `'자정에 새로 시작한다. 셋을 따로 받는다.'` |
| `game_screen.dart` · `menu_grid.dart` '콘텐츠' | `PixelIcon.gate` | `'던전은 표를 쓴다. 층 이동은 깬 층까지 갈 수 있다.'` |
| `game_screen.dart` '대장간' | `PixelIcon.hammer` | `'강화석으로 장비를 만든다. 두드릴수록 좋은 것이 나온다.'` |
| `menu_grid.dart` '도감' | `PixelIcon.book` | `'만난 몬스터가 등록된다. 등록할수록 패시브가 오른다.'` |
| `equipment_panel.dart` `_openCompare` (제목은 부위 이름) | `PixelIcon.shield` | 없음 |

`menu_grid.dart`의 `_open` 도우미도 함께 고친다:

```dart
  void _open(BuildContext context, String title, PixelIcon icon, Widget child,
      {String? help, double heightFactor = 0.72}) {
    Navigator.of(context).pop();
    showGamePopup(context, title: title, icon: icon, help: help, heightFactor: heightFactor, child: child);
  }
```

호출 네 곳(콘텐츠·출석·오늘·도감)을 새 서명에 맞춘다. 예:

```dart
      HudButton(label: '콘텐츠', icon: PixelIcon.gate, badge: '${state.dungeon.tickets}',
          onTap: () => _open(context, '콘텐츠', PixelIcon.gate, const ContentsPanel(),
              help: '던전은 표를 쓴다. 층 이동은 깬 층까지 갈 수 있다.')),
```

- [ ] **Step 7: 테스트와 정적 분석을 돌린다**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze `No issues found!`, 테스트 251개 통과(248 + 새 테스트 3).

깨지면 대개 둘 중 하나다. (가) `heightFactor` 가 큰 팝업이 이제 낮아져 안쪽 목록이 넘친다 — `ListView`는 스크롤되니 문제없지만 `Column`이면 `RenderFlex overflow`가 난다. 그 팝업의 내용을 `ListView`나 `SingleChildScrollView`로 감싸라. (나) `find.text('X')` 처럼 옛 닫기 단추를 찾던 테스트 — 새 원형 칩도 글자는 `'X'` 라 그대로 통과해야 한다. 다른 이유로 깨지면 리포트에 원문을 적어라.

- [ ] **Step 8: 캡처를 만들어 눈으로 본다**

```bash
cd flutter && flutter test test/ui/art_gallery_test.dart 2>&1 | tail -3 && ls -la build/*.png
```

`build/app_screen.png`를 열어 확인하고 리포트에 적어라: 팝업 아래로 하단 5칸과 우하단 스킬칸이 **가려지지 않고 보이는가**. 안 보이면 `hudBottomInset` 계산이 틀린 것이니 실측값을 리포트에 적어라.

- [ ] **Step 9: 커밋**

```bash
git add flutter/lib/ui flutter/test/ui/game_screen_test.dart
git commit -m "feat(flutter): 팝업 골격 — 리본에 아이콘과 도움말, 닫기는 원, 하단 HUD를 안 덮는다

폭 460 고정을 풀어 좁은 화면에서도 화면 안에 들어간다.
하단 HUD 높이를 hud_metrics.dart 상수 둘로 뽑아 팝업과 무대 글자가
같은 숫자를 본다 — 각자 재다가 1px 간격이 났던 자리다.

스펙 4.1·4.2·4.6.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 2: 좌측 초상 열 — 팝업 밖에 남고, 누르면 내용만 바뀐다

스펙 4.3. 지금 `party_row.dart`가 `showGamePopup`을 직접 부르는 탓에 초상을 팝업 안에 두면 팝업 위에 팝업이 뜬다. 라우팅을 밖으로 빼는 것이 먼저다.

**Files:**
- Create: `flutter/lib/ui/hud/portrait_tile.dart`
- Create: `flutter/lib/ui/hud/target_popup.dart`
- Modify: `flutter/lib/ui/party_row.dart` (`PartyPortraits`)
- Modify: `flutter/lib/ui/game_screen.dart` (초상 줄과 '장비' 단추)
- Test: `flutter/test/ui/game_screen_test.dart`

**Interfaces:**
- Consumes: Task 1의 `GamePopup(... leading: Widget?)`, `showGamePopup(..., required PixelIcon icon)`
- Produces:
  - `enum PopupTarget { hero, pet, ally }` — 각 값에 `portraitLabel`·`title`·`icon`·`help`·`locked`
  - `class PortraitTile extends StatelessWidget` — `({required String label, required Widget child, required VoidCallback? onTap, bool alert = false, bool locked = false, bool selected = false})`
  - `Future<void> showTargetPopup(BuildContext context, PopupTarget target)`
  - `PartyPortraits({required ValueChanged<PopupTarget> onSelect})`

**결정 — 동료 칸**: 지금은 누르면 스낵바가 뜬다. 앞으로는 팝업이 열리고 본문에 '동료 — 준비 중'이 뜬다. 스펙 4.3이 초상 셋을 모두 대상으로 세기 때문이다. **여전히 기능은 없다** — 준비 중 문구만 자리를 지킨다. 잠금 규칙을 어기는 것이 아니다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`flutter/test/ui/game_screen_test.dart` 끝에 넣는다. import에 `import 'package:app_game_demo/ui/hud/portrait_tile.dart';` 를 더한다.

```dart
  testWidgets('장비 팝업 왼쪽에 초상 열이 붙고 펫으로 갈아 끼운다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('장비').first);
    await tester.pumpAndSettle();

    // 초상 열은 팝업 본체 **밖 왼쪽**에 있다 (스펙 4.3).
    final body = tester.getRect(find.byKey(const Key('popup-body')));
    final column = tester.getRect(find.byType(PortraitTile).first);
    expect(column.right, lessThanOrEqualTo(body.left),
        reason: '초상은 팝업 위가 아니라 옆이다');

    // 팝업 열의 펫 초상을 누르면 팝업이 새로 뜨지 않고 내용만 바뀐다.
    expect(find.byKey(const Key('popup-body')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('popup-portrait-pet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('popup-body')), findsOneWidget,
        reason: '팝업 위에 팝업이 뜨면 안 된다 — 본문이 둘이면 창이 쌓인 것이다');
    expect(find.text('부화'), findsWidgets, reason: '펫 화면으로 바뀌었다');
  });
```

**왜 `Key`로 찾는가**: 팝업이 열리면 화면에 `PortraitTile` 이 여섯 개다 — 우하단 HUD 줄 셋과
팝업 왼쪽 열 셋. `find.byType(...).at(1)` 은 HUD 줄의 펫을 집는데, 그 자리는 팝업 막에
가려 눌리지 않는다. 그래서 팝업 열의 칸에만 `ValueKey('popup-portrait-<대상>')` 를 붙인다
(Step 4의 `_PortraitColumn` 참조).

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/ui/game_screen_test.dart 2>&1 | tail -20
```

기대: `portrait_tile.dart` 가 없어 컴파일 실패.

- [ ] **Step 3: 초상 칸과 대상 열거형을 만든다**

`flutter/lib/ui/hud/portrait_tile.dart`:

```dart
import 'package:flutter/material.dart';

import 'pixel_icons.dart';
import 'pixel_ui.dart';

/// 팝업이 다루는 대상. 초상 열이 이 셋을 세운다(스펙 4.3).
///
/// 우하단 HUD 줄과 팝업 왼쪽 열이 같은 목록을 쓴다 — 둘이 갈라지면
/// "초상을 눌렀는데 다른 것이 열린다"가 된다.
enum PopupTarget {
  hero('주인공', '장비', PixelIcon.shield, '왼쪽은 입은 것, 오른쪽은 가방. 가방을 눌러 비교한다.'),
  pet('펫', '펫', PixelIcon.egg, '알을 부화하고 용을 탐험 보낸다. 둘 다 시간이 지나야 끝난다.'),
  ally('동료', '동료', PixelIcon.flag, null);

  const PopupTarget(this.portraitLabel, this.title, this.icon, this.help);

  /// 초상 아래 글자. 펫은 등급 이름이 있으면 그것으로 덮어쓴다.
  final String portraitLabel;

  /// 팝업 제목.
  final String title;

  final PixelIcon icon;
  final String? help;

  /// 아직 안 열린 대상. 자리는 있고 내용이 없다.
  bool get locked => this == PopupTarget.ally;
}

/// 초상 한 칸. 아직 그림이 없어 글자나 아이콘으로 채운다 — 초상화는 스펙 5.3.
class PortraitTile extends StatelessWidget {
  const PortraitTile({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.alert = false,
    this.locked = false,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  /// 빨간 점.
  final bool alert;

  /// 아직 없는 대상. 흐리게 그린다.
  final bool locked;

  /// 팝업 왼쪽 열에서 지금 보고 있는 대상. 테두리를 금색으로 바꾼다.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PixelPanel(
                  padding: EdgeInsets.zero,
                  color: PixelPalette.panelLight,
                  border: selected ? PixelPalette.gold : PixelPalette.ink,
                  child: SizedBox(width: 34, height: 34, child: Center(child: child)),
                ),
                if (alert)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      width: 9, height: 9,
                      decoration: const BoxDecoration(color: Color(0xFFE5534B), shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            PixelText(label, size: 8, color: PixelPalette.textDim),
          ],
        ),
      ),
    );
  }
}

/// 대상의 얼굴. 그림이 들어오기 전까지 글자와 아이콘으로 버틴다.
Widget portraitFace(PopupTarget target) => switch (target) {
      PopupTarget.hero => const PixelText('나', size: 12, color: PixelPalette.gold),
      PopupTarget.pet => PixelIconView(PixelIcon.egg, size: 16),
      PopupTarget.ally => const PixelText('L', size: 10),
    };
```

- [ ] **Step 4: 대상형 팝업을 만든다**

`flutter/lib/ui/hud/target_popup.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../equipment_panel.dart';
import '../pet_panel.dart';
import 'game_popup.dart';
import 'pixel_ui.dart';
import 'portrait_tile.dart';

/// 대상이 있는 팝업 — 왼쪽 초상 열에서 주인공·펫·동료를 갈아 끼운다(스펙 4.3).
///
/// 초상은 팝업 **밖** 왼쪽에 남는다. 눌러도 창이 새로 뜨지 않고 안쪽 내용만 바뀐다.
/// 창이 쌓이면 뒤로 가기가 몇 번인지 알 수 없게 된다.
Future<void> showTargetPopup(BuildContext context, PopupTarget target) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _TargetPopup(initial: target),
  );
}

class _TargetPopup extends StatefulWidget {
  const _TargetPopup({required this.initial});

  final PopupTarget initial;

  @override
  State<_TargetPopup> createState() => _TargetPopupState();
}

class _TargetPopupState extends State<_TargetPopup> {
  late PopupTarget _target = widget.initial;

  @override
  Widget build(BuildContext context) {
    return GamePopup(
      title: _target.title,
      icon: _target.icon,
      help: _target.help,
      leading: _PortraitColumn(
        selected: _target,
        onSelect: (t) => setState(() => _target = t),
      ),
      child: switch (_target) {
        PopupTarget.hero => const EquipmentPanel(),
        PopupTarget.pet => const PetPanel(),
        PopupTarget.ally => const Center(
            child: PixelText('동료 — 준비 중', size: 12, color: PixelPalette.textDim),
          ),
      },
    );
  }
}

/// 팝업 왼쪽에 세로로 서는 초상 열. AUTO는 전투 조작이라 여기 없다.
class _PortraitColumn extends ConsumerWidget {
  const _PortraitColumn({required this.selected, required this.onSelect});

  final PopupTarget selected;
  final ValueChanged<PopupTarget> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in PopupTarget.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PortraitTile(
              // 테스트가 HUD 줄의 같은 초상과 구별할 수 있게 팝업 열에만 이름을 준다.
              key: ValueKey('popup-portrait-${t.name}'),
              label: t == PopupTarget.pet
                  ? (state.pets.active?.grade.label ?? t.portraitLabel)
                  : t.portraitLabel,
              alert: t == PopupTarget.pet && state.hatchery.hasReady,
              locked: t.locked,
              selected: t == selected,
              onTap: () => onSelect(t),
              child: portraitFace(t),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: `PartyPortraits`에서 라우팅을 걷어낸다**

`flutter/lib/ui/party_row.dart`를 아래로 **통째로 교체**한다. `_Portrait` 는 `PortraitTile` 로 옮겨 갔으니 사라진다.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/skill.dart';
import 'hud/pixel_icons.dart';
import 'hud/pixel_ui.dart';
import 'hud/portrait_tile.dart';

/// 우하단 초상 줄 — AUTO · 주인공 · 펫 · 동료.
///
/// 같이 싸우는 것들이 한 줄에 선다. 무엇을 열지는 이 위젯이 정하지 않는다 —
/// 팝업 왼쪽 열도 같은 초상을 쓰는데, 거기서는 창을 새로 띄우면 안 되기 때문이다.
class PartyPortraits extends ConsumerWidget {
  const PartyPortraits({super.key, required this.onSelect});

  /// 초상을 눌렀을 때. HUD에서는 팝업을 열고, 팝업 안에서는 내용을 바꾼다.
  final ValueChanged<PopupTarget> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final allAuto = List.generate(SkillState.slots, state.skills.isAuto).every((a) => a);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AUTO — 셋 다 켜져 있으면 끄고, 하나라도 꺼져 있으면 다 켠다.
        GestureDetector(
          onTap: () {
            for (var i = 0; i < SkillState.slots; i++) {
              if (state.skills.isAuto(i) == allAuto) controller.toggleSkillAuto(i);
            }
          },
          child: PixelPanel(
            padding: const EdgeInsets.all(6),
            color: allAuto ? PixelPalette.goldDark : PixelPalette.panelDark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PixelIconView(PixelIcon.auto, size: 14),
                const PixelText('AUTO', size: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        for (final t in PopupTarget.values) ...[
          PortraitTile(
            label: t == PopupTarget.pet
                ? (state.pets.active?.grade.label ?? t.portraitLabel)
                : t.portraitLabel,
            alert: t == PopupTarget.pet && state.hatchery.hasReady,
            locked: t.locked,
            onTap: () => onSelect(t),
            child: portraitFace(t),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }
}
```

마지막 `SizedBox(width: 4)`가 줄 끝에 하나 남는다. 오른쪽 여백이 4px 늘 뿐이라 그대로 둔다 — 조건을 붙이면 코드만 복잡해진다.

- [ ] **Step 6: 화면이 새 서명을 쓰게 한다**

`flutter/lib/ui/game_screen.dart`:

1. import에 `import 'hud/portrait_tile.dart';` 와 `import 'hud/target_popup.dart';` 를 더한다.
2. 우하단 `const PartyPortraits()` 를 바꾼다. `const` 가 빠지므로 `children: const [...]` 도 풀어야 한다:

```dart
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PartyPortraits(onSelect: (t) => showTargetPopup(context, t)),
                  const SizedBox(height: 6),
                  const SkillBar(),
                ],
              ),
```

3. 하단 5칸의 '장비' 단추가 대상형 팝업을 열게 한다:

```dart
                  HudButton(
                    label: '장비',
                    icon: PixelIcon.shield,
                    alert: state.equipment.canEnhance || state.equipment.inventory.isNotEmpty,
                    onTap: () => showTargetPopup(context, PopupTarget.hero),
                  ),
```

4. `_showGrowthHint` 안의 '장비'·'펫' 단추도 같은 방식으로 바꾼다:

```dart
                HudButton(
                  label: '장비',
                  icon: PixelIcon.shield,
                  onTap: () => showTargetPopup(context, PopupTarget.hero),
                ),
                HudButton(
                  label: '펫',
                  icon: PixelIcon.egg,
                  onTap: () => showTargetPopup(context, PopupTarget.pet),
                ),
```

5. 이제 안 쓰는 import(`equipment_panel.dart`, `pet_panel.dart`)가 생겼는지 `flutter analyze` 로 확인하고, **내 변경이 만든 것만** 지운다. `menu_grid.dart`의 '강화' 칸은 여전히 잠금이므로 건드리지 마라.

- [ ] **Step 7: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, 252개 통과(251 + 새 테스트 1).

`party_row` 를 직접 만들던 기존 테스트가 있으면 `onSelect: (_) {}` 를 넘기도록 고쳐라.

- [ ] **Step 8: 커밋**

```bash
git add flutter/lib/ui flutter/test/ui/game_screen_test.dart
git commit -m "feat(flutter): 팝업 왼쪽 초상 열 — 눌러도 창이 쌓이지 않는다

초상 줄이 팝업 밖 왼쪽에 서고, 누르면 팝업 내용만 바뀐다.
PartyPortraits가 직접 팝업을 열던 것을 onSelect로 밖에 맡겼다 —
같은 초상이 HUD에서는 창을 열고 팝업 안에서는 내용을 바꿔야 한다.

스펙 4.3.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 3: 본문 2단과 단별 일괄 단추

스펙 4.4(왼쪽 = 지금 붙어 있는 것, 오른쪽 = 고를 수 있는 목록), 4.5(일괄 버튼은 **각 단 아래에 따로**), 4.7(위험한 동작에는 붉은 경고 한 줄).

지금 `EquipmentPanel`은 2단을 손으로 짰고, 일괄 단추 둘이 **한 줄에 나란히** 있다. 스펙은 각 단 아래다.

**Files:**
- Create: `flutter/lib/ui/hud/popup_two_pane.dart`
- Modify: `flutter/lib/ui/equipment_panel.dart` (`EquipmentPanel.build`)
- Test: `flutter/test/ui/game_screen_test.dart`

**Interfaces:**
- Produces:
  - `class PopupPane extends StatelessWidget` — `({required Widget child, Widget? action, String? warning})`
  - `class PopupTwoPane extends StatelessWidget` — `({required PopupPane left, required PopupPane right})`
- Consumes: Task 2의 `showTargetPopup` 이 `EquipmentPanel` 을 팝업 본문으로 넣는다

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
  testWidgets('일괄 단추가 각 단 아래에 따로 서고 분해에 경고가 붙는다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('장비').first);
    await tester.pumpAndSettle();

    final auto = tester.getRect(find.text('자동 장착').first);
    final scrap = tester.getRect(find.text('일괄 분해').first);
    expect(auto.center.dx, lessThan(scrap.center.dx), reason: '왼쪽 단 아래 · 오른쪽 단 아래 (스펙 4.5)');

    final body = tester.getRect(find.byKey(const Key('popup-body')));
    expect(auto.center.dx, lessThan(body.center.dx), reason: '자동 장착은 왼쪽 단 안이다');
    expect(scrap.center.dx, greaterThan(body.center.dx), reason: '일괄 분해는 오른쪽 단 안이다');
  });
```

가방이 비어 있으면 경고 줄이 안 뜬다. 경고는 테스트하지 않고 눈으로 확인한다 — 가방을 채우려면 도메인을 건드려야 하는데 이 계획은 그러지 않는다.

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/ui/game_screen_test.dart 2>&1 | tail -20
```

기대: 두 단추가 지금은 한 줄에 `spaceEvenly` 로 있어 `scrap.center.dx` 가 본문 중앙보다 왼쪽일 수 있다 — 어느 단언에서 깨졌는지 리포트에 적어라. 통과하면 멈추고 보고하라.

- [ ] **Step 3: 2단 위젯을 만든다**

`flutter/lib/ui/hud/popup_two_pane.dart`:

```dart
import 'package:flutter/material.dart';

import 'pixel_ui.dart';

/// 팝업 본문 한 단. 아래에 그 단만의 일괄 단추와 경고가 붙는다(스펙 4.5·4.7).
class PopupPane extends StatelessWidget {
  const PopupPane({super.key, required this.child, this.action, this.warning});

  final Widget child;

  /// 이 단에만 걸리는 일괄 단추. 없으면 자리를 안 만든다.
  final Widget? action;

  /// 되돌릴 수 없는 동작에 붙는 붉은 한 줄. 단추 바로 위에 선다.
  final String? warning;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        if (warning != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: PixelText(warning!, size: 9, color: PixelPalette.hpLow),
          ),
        if (action != null)
          Padding(padding: const EdgeInsets.all(6), child: action!),
      ],
    );
  }
}

/// 팝업 본문 2단 — 왼쪽은 지금 붙어 있는 것, 오른쪽은 고를 수 있는 목록(스펙 4.4).
///
/// 여덟 화면이 같은 문법을 쓴다. 어느 창을 열어도 왼쪽이 "내 것",
/// 오른쪽이 "바꿀 것"이라 매번 새로 읽지 않아도 된다.
class PopupTwoPane extends StatelessWidget {
  const PopupTwoPane({super.key, required this.left, required this.right});

  final PopupPane left;
  final PopupPane right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: 6),
        Expanded(child: right),
      ],
    );
  }
}
```

- [ ] **Step 4: 장비 화면이 2단 위젯을 쓰게 한다**

`flutter/lib/ui/equipment_panel.dart`의 `EquipmentPanel.build` 의 `return` 문을 아래로 교체한다. `_openCompare`·`_CompareCard`·`_EnhanceCard`·`_SlotTile`·`_BagTile`·`_Button` 은 그대로 둔다.

import에 `import 'hud/popup_two_pane.dart';` 를 더한다.

```dart
    return PopupTwoPane(
      // ── 왼쪽: 입고 있는 것과 강화
      left: PopupPane(
        action: _Button(
          label: '자동 장착',
          enabled: eq.inventory.isNotEmpty,
          onTap: controller.autoEquip,
        ),
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            _EnhanceCard(equipment: eq, config: config, onEnhance: controller.enhance),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.1,
              children: [
                for (final slot in EquipSlot.values)
                  _SlotTile(slot: slot, item: eq.equipped[slot]),
              ],
            ),
          ],
        ),
      ),
      // ── 오른쪽: 가방
      right: PopupPane(
        warning: eq.inventory.isEmpty ? null : '분해한 장비는 되돌릴 수 없습니다',
        action: _Button(
          label: '일괄 분해',
          enabled: eq.inventory.isNotEmpty,
          onTap: controller.scrapAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
              child: PixelText('가방 ${eq.inventory.length}', size: 11, color: PixelPalette.textDim),
            ),
            Expanded(
              child: eq.inventory.isEmpty
                  ? const Center(child: PixelText('비어 있음', size: 11, color: PixelPalette.textDim))
                  : GridView.builder(
                      padding: const EdgeInsets.all(2),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 5,
                        crossAxisSpacing: 5,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: eq.inventory.length,
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => _openCompare(context, ref, i),
                        child: _BagTile(item: eq.inventory[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
```

- [ ] **Step 5: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, 253개 통과(252 + 새 테스트 1).

- [ ] **Step 6: 커밋**

```bash
git add flutter/lib/ui flutter/test/ui/game_screen_test.dart
git commit -m "feat(flutter): 본문 2단 골격 — 일괄 단추가 각 단 아래에 따로 선다

왼쪽은 지금 붙어 있는 것, 오른쪽은 고를 수 있는 목록. 여덟 화면이
같은 문법을 쓰면 어느 창을 열어도 다시 읽지 않아도 된다.
일괄 분해에는 되돌릴 수 없다는 붉은 한 줄을 붙였다.

스펙 4.4·4.5·4.7.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 4: 획득 연출에 아이콘, 그리고 문서

스펙 4.8은 "화면 어둡게 → 띠 → 결과 → 아이콘 → '빈 곳을 터치하세요'"다. `showRewardPopup`이 아이콘만 빼고 이미 그렇게 한다.

**결정 — 아이콘 자리**: "결과 → 아이콘"을 *'결과' 글자 다음, 보상 줄 앞*으로 읽는다. 큰 아이콘이 먼저 눈에 들어오고 그 아래 숫자가 오는 것이 획득 연출의 보통 순서다.

**Files:**
- Modify: `flutter/lib/ui/hud/reward_popup.dart` (`showRewardPopup`, `_RewardOverlay`)
- Modify: `flutter/lib/ui/game_screen.dart`, `flutter/lib/ui/quest_strip.dart`, `flutter/lib/ui/attendance_panel.dart` (호출부 3곳)
- Modify: `docs/superpowers/specs/2026-09-05-screen-map-design.md`
- Modify: `docs/BACKLOG.md`
- Test: `flutter/test/ui/game_screen_test.dart`

**Interfaces:**
- Produces: `showRewardPopup(BuildContext context, {String title = '보상', PixelIcon icon = PixelIcon.growth, required List<String> lines})`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
  testWidgets('획득 연출에 아이콘이 있다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showRewardPopup(context, title: '출석 보상',
              icon: PixelIcon.check, lines: const['골드 +100']),
          child: const Text('열기'),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byType(PixelIconView), findsWidgets, reason: '스펙 4.8의 아이콘');
    expect(find.text('골드 +100'), findsWidgets);
    expect(find.text('빈 곳을 터치하세요'), findsWidgets);
  });
```

import에 `import 'package:app_game_demo/ui/hud/reward_popup.dart';` 를 더한다. `PixelIconView`는 `pixel_icons.dart`에 있다.

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/ui/game_screen_test.dart 2>&1 | tail -20
```

기대: `icon` 인자가 없어 컴파일 실패.

- [ ] **Step 3: 아이콘을 넣는다**

`flutter/lib/ui/hud/reward_popup.dart`:

1. import에 `import 'pixel_icons.dart';` 를 더한다(없으면).
2. `showRewardPopup` 서명에 `PixelIcon icon = PixelIcon.growth,` 를 더하고 `_RewardOverlay(title: title, icon: icon, lines: lines)` 로 넘긴다.
3. `_RewardOverlay`에 `final PixelIcon icon;` 필드와 생성자 인자 `required this.icon` 을 더한다.
4. `const PixelText('결과', ...)` 와 보상 줄 사이에 아이콘을 넣는다:

```dart
            const PixelText('결과', size: 12, color: PixelPalette.textDim),
            const SizedBox(height: 10),
            PixelPanel(
              padding: const EdgeInsets.all(10),
              border: PixelPalette.gold,
              child: PixelIconView(icon, size: 36),
            ),
            const SizedBox(height: 12),
```

- [ ] **Step 4: 호출부 3곳에 아이콘을 준다**

```bash
cd flutter && grep -rn "showRewardPopup(" lib
```

| 파일 | 무엇 | `icon:` |
|---|---|---|
| `game_screen.dart` | 던전 클리어 | `PixelIcon.gate` |
| `quest_strip.dart` | 퀘스트 보상 | `PixelIcon.check` |
| `attendance_panel.dart` | 출석 보상 | `PixelIcon.calendar` |

- [ ] **Step 5: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, 254개 통과(253 + 새 테스트 1).

- [ ] **Step 6: 스펙에 실제와 다른 곳을 적는다**

`docs/superpowers/specs/2026-09-05-screen-map-design.md` 의 4절 마지막 줄(`8. 획득은 전부 같은 연출...`) **다음**에 빈 줄을 두고 붙인다:

```markdown
**2026-09-05 구현 뒤 실제와 다른 곳**: 4.3의 초상 열은 **대상형 팝업(주인공·펫·동료)에만** 붙는다.
성장·대장간·콘텐츠처럼 대상이 없는 창에는 초상이 없다.
4.6은 **"보인다"까지만** 지켜진다 — 팝업이 하단 바와 우하단 스킬칸 자리를 비우지만,
바깥을 덮은 막이 탭을 먹어 **팝업을 먼저 닫아야 누를 수 있다.** 창을 띄운 채 하단 바를
누르려면 팝업이 라우트가 아니어야 한다(백로그 D5-1).
4.1의 `?` 도움말은 상주 화면 아홉 곳에만 있다. 잠깐 뜨는 창(비교·오프라인 보상·패배 안내)에는 없다.
```

- [ ] **Step 7: 백로그에 남긴다**

`docs/BACKLOG.md` 의 `### D4-3.` 항목 **아래**에 붙인다:

```markdown
### D5-1. 팝업을 띄운 채 하단 바를 누르기 · M
스펙 4.6은 "팝업이 떠도 하단 바와 우하단 스킬칸은 계속 보인다"다. 지금은 자리를 비워 **보이기는 하지만**
`showDialog`의 막이 탭을 먹어 누를 수 없다. 창을 갈아 끼우려면 두 번 눌러야 한다(닫기 → 열기).
막에 구멍을 뚫는 방법은 없다 — 팝업을 라우트가 아니라 `game_screen.dart` Stack 안의 한 겹으로
바꿔야 한다. 호출부 15곳과 `Navigator.pop()` 을 쓰는 안쪽 창(장비 비교 등)이 같이 바뀐다.
**아트가 들어온 뒤에** 한다. 지금 바꾸면 화면이 또 흔들린다.
```

- [ ] **Step 8: 커밋**

```bash
git add flutter/lib/ui flutter/test/ui/game_screen_test.dart docs/superpowers/specs/2026-09-05-screen-map-design.md docs/BACKLOG.md
git commit -m "feat(flutter): 획득 연출에 아이콘 — 스펙 4절 골격 완결

결과 글자와 보상 줄 사이에 큰 아이콘을 넣었다. 던전은 문, 퀘스트는 체크,
출석은 달력이다.

스펙 4절에 실제와 다른 곳 세 가지를 적고, 팝업을 띄운 채 하단 바를
누르는 것은 백로그 D5-1로 넘겼다.

스펙 4.8.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

## 이 계획이 하지 않는 것

- **새 화면을 만들지 않는다.** 소환·상점·전용무기·동료·영지·아레나·랭킹·계정은 계속 잠겨 있다.
- **`lib/domain`·`lib/app`을 안 건드린다.** 게임 규칙은 그대로다.
- **팝업을 비모달로 바꾸지 않는다** (백로그 D5-1). 스펙 4.6의 "보인다"까지만 한다.
- **좁은 폭(논리 660 미만)의 HUD 겹침을 안 고친다** (백로그 D4-2). 팝업 폭은 이 계획에서 유동으로 바뀌지만, 상단 중앙 `StageStatus(300)` 과 하단 중앙 5칸은 그대로다.
- **초상화 그림을 안 그린다.** 초상 칸은 글자와 아이콘으로 버틴다 (스펙 5.3).
- **`?` 도움말을 문서 페이지로 만들지 않는다.** 한 줄짜리 설명 창이면 충분하다.

## 알려진 위험

| 위험 | 어디서 터지나 | 대응 |
|---|---|---|
| `heightFactor` 큰 팝업이 낮아져 안쪽이 넘친다 | Task 1 Step 7 | 안쪽이 `Column`이면 `ListView`로 감싼다. `ListView`면 그냥 스크롤된다 |
| `showGamePopup`에 `icon` 을 필수로 만들어 14곳이 동시에 깨진다 | Task 1 Step 6 | 의도한 것이다. `grep -rn "showGamePopup(" lib` 로 전부 찾아 한 번에 고친다 |
| `PixelText`가 `Stack` 안 `Text` 둘이라 도움말이 두 줄이 되면 어긋나 보인다 | Task 1 Step 4 | 둘이 같은 폭 제약을 받아 같은 자리에서 줄바꿈한다. 도움말은 `SizedBox(width: 300)` 안에 든다 |
| `find.text('X')` 로 닫기를 찾던 기존 테스트 | Task 1 Step 7 | 원형 칩도 글자는 `'X'` 라 그대로 찾힌다 |
| 초상 열이 팝업 밖에 나가 좁은 화면에서 잘린다 | Task 2 | `GamePopup`이 `leading` 이 있으면 본체 폭에서 44를 뺀다. 440폭 테스트가 지킨다 |
| 동료 초상이 이제 팝업을 연다 — "잠금인데 화면이 열렸다"로 읽힌다 | Task 2 리뷰 | 본문은 '동료 — 준비 중' 한 줄뿐이다. 기능이 아니다. 리뷰어에게 이 문단을 가리켜라 |
| `PopupPane`의 `Expanded`가 높이 없는 곳에 놓인다 | Task 3 | `PopupTwoPane`은 `GamePopup`의 `Expanded` 안에서만 쓴다. 다른 곳에 쓰면 터진다 |
| 가방이 비어 경고 줄을 눈으로 못 본다 | Task 3 Step 5 | 캡처로는 안 보인다. 리포트에 "가방이 비어 경고 미확인"이라고 적어라 |
