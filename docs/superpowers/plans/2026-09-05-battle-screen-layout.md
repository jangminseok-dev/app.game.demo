# 전투 화면 자리 재배치 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 전투 화면의 UI를 화면 지도 스펙의 **일곱 자리**로 옮기고, 우상단 `≡`로 여는 **메뉴 그리드**와 `던전/도전` 2탭 **콘텐츠 팝업**을 만든다. 아직 없는 기능(소환·상점·전용무기·동료 등)은 **자리만 잡고 잠금 표시**한다 — 새 기능을 만들지 않는다.

**Architecture:** `game_screen.dart`의 `build()` Stack을 통째로 다시 쓴다(Task 3). 그 위에 세 부품을 새로 만든다 — 우하단 초상 줄(Task 4), 메뉴 그리드·콘텐츠 팝업(Task 5), 좌상단/상단중앙으로 갈라진 HUD(Task 6). 기존 위젯(`QuestStrip`·`SkillBar`·`HudButton`·각 패널)은 그대로 쓰고 자리만 옮긴다. 도메인은 건드리지 않는다.

**Tech Stack:** Flutter + Riverpod. `pixel_ui.dart`의 `PixelPanel`·`PixelText`·`PixelGauge`·`CurrencyChip`, `game_popup.dart`의 `HudButton`·`showGamePopup`.

**Spec:** `docs/superpowers/specs/2026-09-05-screen-map-design.md` 2절(자리와 성격)·3절(메뉴 그리드). 팝업 골격(4절 — 좌측 초상 열·2단·일괄 버튼)은 **다음 계획**이다.

## Global Constraints

스펙에서 그대로 옮긴 값이다.

- **자리 일곱 개** (스펙 2절 표):

  | 자리 | 우리 것 |
  |---|---|
  | 좌상단 | ⚔전투력 / 골드 · 젬 (Lv·이름은 계정 시스템이 없어 **미룬다**) |
  | 좌측 | 퀘스트 카드 (`QuestStrip`) |
  | 좌측 아래 | 출석부 · 오늘 과제 |
  | 좌하단 | 광고 아이콘 **자리만** (SDK는 백로그 C3) |
  | 상단 중앙 | 층 이름 · 제한 시간 막대 · `x`남은 수 (배속은 **미룬다** — 스펙 9절) |
  | 우상단 | 콘텐츠 · 소환 · 상점 · `≡` |
  | 하단 중앙 | 장비 · 스킬 · **[대장간 큰 원형]** · 전용무기 · 성장 |
  | 우하단 | `AUTO` · 초상(주인공·펫·동료) · 스킬 3칸 |

- **메뉴 그리드 4열** (스펙 3절): `콘텐츠·소환·상점·✕` / `캐릭터·강화·영지·동료` / `출석·오늘 과제·랭킹·도감` / `도움말·설정`
- **콘텐츠 팝업은 `던전` / `도전` 2탭.** 던전 탭 = 기존 `DungeonPanel` + `StageSelectPanel`(층 이동). 도전 탭 = 비어 있음(아레나는 3등급)
- **없는 기능은 잠금 단추.** 소환 · 상점 · 전용무기 · 동료 · 캐릭터 · 강화 · 영지 · 랭킹 · 도움말 · 설정 · 도전. 누르면 `준비 중` 한 줄 `SnackBar`. **이 계획에서 그 기능을 만들지 않는다**
- **`ConstrainedBox(maxWidth: 480)`을 지운다.** 세로 시절 잔재이고, GameWidget 뷰포트를 줄여 cover 배율을 망친다(백로그 D4-1)
- **`SafeArea`로 감싼다.** 가로 폰은 노치가 좌우에 있다
- **도메인(`lib/domain/`)은 건드리지 않는다.** `game_controller.dart`도 — `toggleSkillAuto(int)`가 이미 있다
- 색은 `pixel_ui.dart`의 `PixelPalette`만. 문체는 평서형·짧게
- **팝업 안쪽(2단·좌측 초상 열)은 안 건드린다.** 다음 계획이다

## File Structure

| 파일 | 책임 | 처리 |
|---|---|---|
| `flutter/lib/ui/game_screen.dart` | 전투 화면 배치 | `build()` Stack 전면 교체 |
| `flutter/lib/ui/hud/game_popup.dart` | `HudButton` | `locked`·`big` 옵션 추가 |
| `flutter/lib/ui/hud/pixel_icons.dart` | 아이콘 | 4종 추가 (`shop`·`menu`·`weapon`·`auto`) |
| `flutter/lib/ui/hud/battle_hud.dart` | 무대 위 HUD | 좌상단 `ProfileBadge`·상단 중앙 `StageStatus`·하단 `MonsterLine` 셋으로 분리 |
| `flutter/lib/ui/party_row.dart` | 초상 줄 | Material 스텁 → 픽셀 `PartyPortraits`로 다시 씀 |
| `flutter/lib/ui/hud/menu_grid.dart` | 메뉴 그리드 팝업 | **신규** |
| `flutter/lib/ui/contents_panel.dart` | 콘텐츠 2탭 | **신규** |
| `flutter/test/ui/game_screen_test.dart` | 화면 테스트 | 단추 라벨 갱신 |
| `docs/BACKLOG.md` | 남은 일 | D4-1 완료 표시 |

---

### Task 1: 폭 제약을 풀고 SafeArea로 감싼다

**Files:**
- Modify: `flutter/lib/ui/game_screen.dart:160-164`

**Interfaces:**
- Consumes: 없음
- Produces: 화면 전체를 쓰는 Stack. Task 3이 그 안을 다시 짠다

**왜 먼저인가**: 전체 리뷰가 확인한 대로 `maxWidth: 480`이 GameWidget 뷰포트를 480으로 줄여 cover가 480 기준으로 계산되고, 무대가 화면보다 좁게 그려져 우측에 37~56px 띠가 남는다. 이걸 풀면 카메라 프레이밍이 통째로 넓어지므로 **다른 자리를 잡기 전에** 풀어야 한다.

- [ ] **Step 1: 지금 코드를 확인한다**

```bash
sed -n '158,166p' flutter/lib/ui/game_screen.dart
```

기대: `body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Stack(`. 주석 `// 세로 게임이라 데스크톱에서도 폰 폭으로 묶는다.`가 있다.

- [ ] **Step 2: 제약을 풀고 SafeArea로 바꾼다**

`fix_constraint.py`로 저장해 실행한다.

```python
# fix_constraint.py
import pathlib
p = pathlib.Path('flutter/lib/ui/game_screen.dart')
s = p.read_text()
old = """      body: Center(
        child: ConstrainedBox(
          // 세로 게임이라 데스크톱에서도 폰 폭으로 묶는다.
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack("""
new = """      // 가로 화면. 노치가 좌우에 오므로 SafeArea로 감싼다.
      // 폭을 묶지 않는다 — 묶으면 GameWidget 뷰포트가 줄어 cover 배율이 화면이 아니라
      // 그 폭 기준으로 계산되고, 무대가 화면보다 좁게 그려져 옆에 띠가 남는다(백로그 D4-1).
      body: SafeArea(
        child: Stack("""
assert old in s, "ConstrainedBox 블록을 못 찾았다"
s = s.replace(old, new, 1)
p.write_text(s)
print("ok")
```

이러면 닫는 괄호가 하나 남는다 — `ConstrainedBox(`가 사라졌으니 그 짝 `)`도 지워야 한다. 파일 끝쪽 `build()`의 닫는 부분을 본다:

```bash
grep -n "^          ),$\|^        ),$\|^      ),$\|^    );$" flutter/lib/ui/game_screen.dart | tail -6
```

`Stack(` 의 닫는 `),`(들여쓰기 10칸) 다음에 `ConstrainedBox`의 닫는 `),`(8칸), `Center`의 `),`(6칸)이 있다. **8칸짜리 `),` 하나를 지운다.** `flutter analyze`가 괄호 짝을 알려 주니 그걸로 확인한다.

- [ ] **Step 3: 컴파일과 테스트**

```bash
cd flutter && flutter analyze lib/ui/game_screen.dart 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 오류 없음, 246 통과.

- [ ] **Step 4: 캡처로 띠가 사라졌는지 본다**

```bash
cd flutter && flutter test test/ui/art_gallery_test.dart 2>&1 | tail -2
python3 -c "
from PIL import Image
im = Image.open('build/app_screen.png').convert('RGB')
w, h = im.size
# 오른쪽 가장자리 세로선 색을 샘플해 배경 띠(#12161A)가 남았는지 본다
col = [im.getpixel((w-2, y)) for y in range(0, h, h//8)]
print('우측 가장자리:', col)
print('띠 색(18,22,26)이 있으면 실패:', any(abs(r-18)<4 and abs(g-22)<4 and abs(b-26)<4 for r,g,b in col))
"
```

기대: `False`. 우측 가장자리가 배경 그림 색이다. **True면 제약이 아직 남아 있는 것** — Step 2를 다시 본다.

- [ ] **Step 5: 커밋**

```bash
git add flutter/lib/ui/game_screen.dart
git commit -m "fix(flutter): 화면 폭 제약을 푼다 — 우측 띠가 사라진다

maxWidth 480이 GameWidget 뷰포트를 줄여 cover 배율이 화면이 아니라
480 기준으로 계산됐다. 무대가 화면보다 좁게 그려져 폰 대부분에서
우측에 37~56px 띠가 남았다(백로그 D4-1).

세로 시절 잔재다. 가로에서는 SafeArea로 노치만 피하면 된다.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: 아이콘 4종

**Files:**
- Modify: `flutter/lib/ui/hud/pixel_icons.dart` (`enum PixelIcon`)

**Interfaces:**
- Consumes: 없음
- Produces: `PixelIcon.shop` · `PixelIcon.menu` · `PixelIcon.weapon` · `PixelIcon.auto`. Task 3·4·5가 쓴다

기존 형식을 따른다 — 12×12 격자를 한 줄 문자열로, `#`이 칠해지는 칸. 지금 11종(`growth shield hammer egg flag gate calendar check pin book spark`)이 있다.

- [ ] **Step 1: 형식을 확인한다**

```bash
sed -n '/^enum PixelIcon/,/^}/p' flutter/lib/ui/hud/pixel_icons.dart | head -8
```

기대: `shield('''....''')` 꼴로 각 값이 144자 문자열을 갖는다. 마지막 값 뒤에 `;`가 붙고 `const PixelIcon(this.art);`가 온다.

- [ ] **Step 2: 4종을 더한다**

`add_icons.py`로 저장해 실행한다. 마지막 값 `spark(...)` 뒤의 `;`를 `,`로 바꾸고 넷을 이어 붙인다.

```python
# add_icons.py
import pathlib, re
p = pathlib.Path('flutter/lib/ui/hud/pixel_icons.dart')
s = p.read_text()

# 12행씩 이어 붙인다. 각 행 12자.
def art(rows):
    assert len(rows) == 12 and all(len(r) == 12 for r in rows), rows
    return "'''" + "".join(rows) + "'''"

shop = art([
    "............",
    ".##########.",
    ".#.#.#.#.#.#",
    ".##########.",
    "..#......#..",
    "..#......#..",
    "..#..##..#..",
    "..#..##..#..",
    "..#..##..#..",
    "..########..",
    "............",
    "............",
])
menu = art([
    "............",
    "............",
    ".##########.",
    ".##########.",
    "............",
    ".##########.",
    ".##########.",
    "............",
    ".##########.",
    ".##########.",
    "............",
    "............",
])
weapon = art([
    ".....##.....",
    ".....##.....",
    ".....##.....",
    ".....##.....",
    ".....##.....",
    ".....##.....",
    "..########..",
    "..########..",
    ".....##.....",
    ".....##.....",
    "....####....",
    "............",
])
auto = art([
    "............",
    "...#........",
    "...##.......",
    "...###......",
    "...####.....",
    "...#####....",
    "...######...",
    "...#####....",
    "...####.....",
    "...###......",
    "...##.......",
    "...#........",
])

# spark(...) 가 마지막 값이다. 그 뒤의 ';' 를 찾아 넷을 끼운다.
m = re.search(r"(spark\('''[.#]{144}'''\))\s*;", s)
assert m, "spark 값을 못 찾았다"
new = (m.group(1) + ",\n"
       f"  /// 상점 — 천막.\n  shop({shop}),\n"
       f"  /// 메뉴 — 가로줄 셋.\n  menu({menu}),\n"
       f"  /// 전용무기 — 세로로 선 검.\n  weapon({weapon}),\n"
       f"  /// 자동 전투 — 재생 삼각형.\n  auto({auto});")
s = s[:m.start()] + new + s[m.end():]
p.write_text(s)
print("ok")
```

- [ ] **Step 3: 컴파일 확인**

```bash
cd flutter && flutter analyze lib/ui/hud/pixel_icons.dart 2>&1 | tail -2
dart -e "print('skip')" 2>/dev/null; grep -c "'''" flutter/lib/ui/hud/pixel_icons.dart
```

기대: analyze 오류 없음. `'''` 개수가 `30`(15종 × 2 — 기존 11종 `growth shield hammer egg flag gate calendar check pin book spark` + 새 4종).

- [ ] **Step 4: 커밋**

```bash
git add flutter/lib/ui/hud/pixel_icons.dart
git commit -m "feat(flutter): 픽셀 아이콘 4종 — 상점·메뉴·전용무기·자동

전투 화면 일곱 자리에 필요한 단추 넷의 그림이다.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: 전투 화면 골격을 일곱 자리로

**Files:**
- Modify: `flutter/lib/ui/hud/game_popup.dart` (`HudButton`에 `locked`·`big`)
- Modify: `flutter/lib/ui/game_screen.dart` (`build()`의 Stack 전면 교체)
- Modify: `flutter/test/ui/game_screen_test.dart:33-35` (단추 라벨)

**Interfaces:**
- Consumes: Task 2의 아이콘 4종
- Produces: 일곱 자리 Stack. Task 4가 우하단 `_PartySlotPlaceholder`를 `PartyPortraits`로, Task 5가 `_showComingSoon` 자리 둘(≡·콘텐츠 도전)을 진짜 팝업으로, Task 6이 `BattleHud`를 셋으로 가른다

**이 태스크가 끝나면**: 자리 일곱 개가 다 있다. 없는 기능은 잠금 단추다. 메뉴 `≡`와 초상 줄은 **임시**(준비 중 / 빈 칸)이고 다음 두 태스크가 채운다. 옛 우측 세로 열(던전·오늘·출석·이동·도감)은 사라지고 그 내용은 새 자리로 간다 — 던전은 콘텐츠, 오늘·출석은 좌측 아래, 이동·도감은 Task 5의 콘텐츠·메뉴로.

- [ ] **Step 1: `HudButton`에 `locked`와 `big`을 더한다**

`fix_hudbutton.py`로 저장해 실행한다.

```python
# fix_hudbutton.py
import pathlib
p = pathlib.Path('flutter/lib/ui/hud/game_popup.dart')
s = p.read_text()

old = """  const HudButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.alert = false,
    this.badge,
  });

  final String label;
  final PixelIcon icon;
  final VoidCallback onTap;

  /// 빨간 점.
  final bool alert;

  /// 숫자 뱃지.
  final String? badge;"""
new = """  const HudButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.alert = false,
    this.badge,
    this.locked = false,
    this.big = false,
  });

  final String label;
  final PixelIcon icon;
  final VoidCallback onTap;

  /// 빨간 점.
  final bool alert;

  /// 숫자 뱃지.
  final String? badge;

  /// 아직 없는 기능. 흐리게 그리고 자물쇠를 얹는다. 누르면 onTap이 '준비 중'을 띄운다.
  final bool locked;

  /// 하단 가운데 하나만 크게. 레퍼런스가 대장간을 그렇게 둔다.
  final bool big;"""
assert old in s, "HudButton 생성자를 못 찾았다"
s = s.replace(old, new, 1)

old2 = """              PixelPanel(
                padding: const EdgeInsets.all(7),
                color: PixelPalette.panelLight,
                child: PixelIconView(icon, size: 20),
              ),"""
new2 = """              Opacity(
                opacity: locked ? 0.45 : 1,
                child: PixelPanel(
                  padding: EdgeInsets.all(big ? 11 : 7),
                  color: big ? PixelPalette.goldDark : PixelPalette.panelLight,
                  child: PixelIconView(icon, size: big ? 28 : 20),
                ),
              ),
              if (locked)
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: PixelPanel(
                    padding: const EdgeInsets.all(2),
                    color: PixelPalette.panelDark,
                    child: const PixelText('🔒', size: 8),
                  ),
                ),"""
assert old2 in s, "HudButton 본체를 못 찾았다"
s = s.replace(old2, new2, 1)
p.write_text(s)
print("ok")
```

`🔒` 이모지가 픽셀 글꼴에 없으면 네모로 나온다. 그러면 `'L'`로 바꾼다 — Task 7 캡처에서 확인한다.

- [ ] **Step 2: `game_screen.dart`의 Stack을 다시 쓴다**

`build()`의 `return Scaffold(` 부터 그 메서드 끝 `);` 까지를 통째로 바꾼다. 아래 본문을 `new_build.dart`로 저장하고, `replace_build.py`로 갈아 끼운다.

```dart
// new_build.dart — game_screen.dart build()의 return 문. 이 파일 통째로 옛 return을 대체한다.
    return Scaffold(
      backgroundColor: const Color(0xFF12161A),
      // 가로 화면. 노치가 좌우에 오므로 SafeArea로 감싼다.
      // 폭을 묶지 않는다 — 묶으면 GameWidget 뷰포트가 줄어 cover 배율이 화면이 아니라
      // 그 폭 기준으로 계산되고, 무대가 화면보다 좁게 그려져 옆에 띠가 남는다(백로그 D4-1).
      body: SafeArea(
        child: Stack(
          children: [
            // ── 전투가 화면을 다 채운다. 위에 얹히는 것은 전부 겹침이다.
            const Positioned.fill(child: BattleArea()),

            // ── 보스 경고 띠
            Positioned(left: 0, right: 0, top: 60, child: BossWarningBanner(animation: _bossWarning)),

            // ── 좌측 · 지금 할 일
            const Positioned(left: 6, top: 64, child: QuestStrip()),

            // ── 좌측 아래 · 시간이 차는 것
            Positioned(
              left: 6,
              bottom: 72,
              child: Row(
                children: [
                  HudButton(
                    label: '출석',
                    icon: PixelIcon.check,
                    alert: state.attendance.canClaim(epochDayOf(DateTime.now())),
                    onTap: () => showGamePopup(context, title: '출석부', heightFactor: 0.55, child: const AttendancePanel()),
                  ),
                  const SizedBox(width: 8),
                  HudButton(
                    label: '오늘',
                    icon: PixelIcon.calendar,
                    alert: anyDailyReady(state),
                    onTap: () => showGamePopup(context, title: '오늘 과제', heightFactor: 0.5, child: const DailyPanel()),
                  ),
                ],
              ),
            ),

            // ── 좌하단 · 바깥 소리 (광고 자리. SDK는 백로그 C3)
            Positioned(
              left: 6,
              bottom: 6,
              child: HudButton(
                label: '광고',
                icon: PixelIcon.spark,
                locked: true,
                onTap: () => _showComingSoon(context, '리워드 광고'),
              ),
            ),

            // ── 우상단 · 바깥으로 나가는 곳
            Positioned(
              right: 6,
              top: 6,
              child: Row(
                children: [
                  HudButton(
                    label: '콘텐츠',
                    icon: PixelIcon.gate,
                    badge: '${state.dungeon.tickets}',
                    alert: state.dungeon.tickets > 0 && state.dungeon.run == null,
                    // Task 5가 던전/도전 2탭 팝업으로 바꾼다. 지금은 던전만.
                    onTap: () => showGamePopup(context, title: '던전', child: const DungeonPanel()),
                  ),
                  const SizedBox(width: 8),
                  HudButton(label: '소환', icon: PixelIcon.spark, locked: true, onTap: () => _showComingSoon(context, '소환')),
                  const SizedBox(width: 8),
                  HudButton(label: '상점', icon: PixelIcon.shop, locked: true, onTap: () => _showComingSoon(context, '상점')),
                  const SizedBox(width: 8),
                  // Task 5가 메뉴 그리드로 바꾼다.
                  HudButton(label: '메뉴', icon: PixelIcon.menu, onTap: () => _showComingSoon(context, '메뉴')),
                ],
              ),
            ),

            // ── 하단 중앙 · 내가 키우는 것. 레퍼런스 5칸과 같은 순서, 가운데만 크게.
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  HudButton(
                    label: '장비',
                    icon: PixelIcon.shield,
                    alert: state.equipment.canEnhance || state.equipment.inventory.isNotEmpty,
                    onTap: () => showGamePopup(context, title: '장비', child: const EquipmentPanel()),
                  ),
                  const SizedBox(width: 10),
                  HudButton(
                    label: '스킬',
                    icon: PixelIcon.spark,
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: PixelPalette.panel,
                      builder: (_) => const SkillSheet(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  HudButton(
                    label: '대장간',
                    icon: PixelIcon.hammer,
                    big: true,
                    alert: state.equipment.canCraft(ref.read(balanceConfigProvider)),
                    onTap: () => showGamePopup(context, title: '대장간', child: const ForgePanel()),
                  ),
                  const SizedBox(width: 10),
                  HudButton(label: '무기', icon: PixelIcon.weapon, locked: true, onTap: () => _showComingSoon(context, '전용무기')),
                  const SizedBox(width: 10),
                  HudButton(
                    label: '성장',
                    icon: PixelIcon.growth,
                    alert: _canBuyAnything(state),
                    onTap: () => showGamePopup(context, title: '성장', child: const _UpgradeTab()),
                  ),
                ],
              ),
            ),

            // ── 우하단 · 같이 싸우는 것. Task 4가 초상 줄을 채운다.
            Positioned(
              right: 6,
              bottom: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _PartySlotPlaceholder(),
                  SizedBox(height: 6),
                  SkillBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 아직 없는 기능을 눌렀을 때. 한 줄만 띄우고 끝낸다.
  void _showComingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: PixelText('$what — 준비 중', size: 12), duration: const Duration(seconds: 1)),
    );
  }
```

```python
# replace_build.py
import pathlib, re
p = pathlib.Path('flutter/lib/ui/game_screen.dart')
s = p.read_text()
body = pathlib.Path('new_build.dart').read_text()

# build()의 'return Scaffold(' 부터 그 메서드를 닫는 '  }\n' 직전까지를 바꾼다.
start = s.index('    return Scaffold(')
# 다음에 나오는 '\n  }\n' 이 build()의 끝이다.
end = s.index('\n  }\n', start) + len('\n  }\n')
s = s[:start] + body.rstrip('\n') + '\n' + s[end:]

# 임시 초상 자리. Task 4가 PartyPortraits로 바꾼다.
placeholder = '''
/// 우하단 초상 줄 자리. Task 4가 채운다.
class _PartySlotPlaceholder extends StatelessWidget {
  const _PartySlotPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 150, height: 44);
}
'''
s = s.rstrip('\n') + '\n' + placeholder
p.write_text(s)
print("ok")
```

`_showComingSoon`이 `build()` 뒤에 붙는다 — `replace_build.py`가 `new_build.dart`의 끝(메서드 하나)까지 넣으므로 `_canBuyAnything` 앞에 들어간다.

- [ ] **Step 3: import를 맞춘다**

새 코드가 `SkillSheet`(이미 `skill_bar.dart`에서 import), `PixelText`·`PixelPalette`(`pixel_ui.dart`, 이미 있음)를 쓴다. 지워진 것: `QuestStrip`을 하단 단추로 여는 코드가 사라졌지만 좌측 카드로 남아 있으니 import는 유지. `StageSelectPanel`·`CodexTab`은 Task 5까지 안 쓰인다 — **import를 지우지 마라**, Task 5가 다시 쓴다. `flutter analyze`가 unused import 경고를 내도 이번엔 둔다.

```bash
cd flutter && flutter analyze lib/ui/game_screen.dart lib/ui/hud/game_popup.dart 2>&1 | tail -6
```

기대: **error 없음.** `unused_import` warning은 허용(Task 5가 쓴다). 그 외 warning은 고친다.

- [ ] **Step 4: 테스트 라벨을 갱신한다**

옛 테스트가 `['성장', '장비', '펫', '퀘스트', '던전']` 단추를 찾는다. 펫은 초상으로(Task 4), 퀘스트는 좌측 카드로, 던전은 콘텐츠로 갔다.

```python
# fix_test_labels.py
import pathlib
p = pathlib.Path('flutter/test/ui/game_screen_test.dart')
s = p.read_text()
old = """    // 기능은 전부 전투 위 단추다.
    for (final label in ['성장', '장비', '펫', '퀘스트', '던전']) {"""
new = """    // 하단 5칸 + 우상단 4칸 + 좌측 아래 2칸. 잠긴 것도 자리는 있다.
    for (final label in ['장비', '스킬', '대장간', '무기', '성장', '콘텐츠', '소환', '상점', '메뉴', '출석', '오늘']) {"""
assert old in s, "라벨 루프를 못 찾았다"
p.write_text(s.replace(old, new, 1))
print("ok")
```

- [ ] **Step 5: 테스트**

```bash
cd flutter && flutter test 2>&1 | tail -5
```

기대: 전부 통과. 깨지면 어느 단언인지 읽어라 — `find.text('성장')`이 `findsWidgets`인데 `_UpgradeTab` 안에도 '성장'이 있으면 둘 이상 잡혀도 `findsWidgets`는 통과한다. `findsOneWidget`을 쓰는 곳이 깨지면 그 테스트가 옛 배치를 전제한 것이니 리포트에 적고 고쳐라.

- [ ] **Step 6: 캡처**

```bash
cd flutter && flutter test test/ui/art_gallery_test.dart 2>&1 | tail -2 && ls -la build/app_screen.png
```

파일을 열어 **일곱 자리가 다 있는지** 본다. 우하단은 빈 칸 + 스킬 바(Task 4 전). 크기·시각을 리포트에.

- [ ] **Step 7: 커밋**

```bash
git add flutter/lib/ui/game_screen.dart flutter/lib/ui/hud/game_popup.dart flutter/test/ui/game_screen_test.dart
git commit -m "feat(flutter): 전투 화면을 일곱 자리로 — 레퍼런스 배치 그대로

좌상단 나 · 좌측 할 일 · 좌측 아래 시간이 차는 것 · 좌하단 바깥 소리 ·
상단 중앙 지금 상태 · 우상단 바깥으로 · 하단 중앙 키우는 것 · 우하단 같이 싸우는 것.
자리마다 성격 한 줄이 있어 새 화면이 늘어도 어디 넣을지 안 물어본다.

하단 5칸은 레퍼런스와 같은 순서다 — 장비·스킬·대장간·무기·성장, 가운데만 크게.
아직 없는 기능(소환·상점·전용무기·광고)은 잠금 단추로 자리만 잡았다.

옛 우측 세로 열은 사라졌다. 던전은 콘텐츠로, 출석·오늘은 좌측 아래로,
이동·도감은 다음 커밋의 콘텐츠·메뉴로 간다.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: 우하단 초상 줄과 AUTO

**Files:**
- Modify: `flutter/lib/ui/party_row.dart` (전면 교체 → `PartyPortraits`)
- Modify: `flutter/lib/ui/game_screen.dart` (`_PartySlotPlaceholder` → `PartyPortraits`, 스텁 삭제)

**Interfaces:**
- Consumes: Task 2 `PixelIcon.auto`·`PixelIcon.egg`, Task 3의 `_PartySlotPlaceholder` 자리, `game_controller.dart`의 `toggleSkillAuto(int)`(이미 있음), `SkillState.auto`(슬롯 3개 bool)
- Produces: `PartyPortraits` 위젯. 다음 계획(팝업 골격)이 이걸 팝업 옆 좌측 열로도 쓴다

**규칙**: `AUTO`는 스킬 슬롯 셋의 `auto`를 **한 번에** 켜고 끈다. 셋 다 켜져 있으면 끄고, 하나라도 꺼져 있으면 다 켠다. 초상은 주인공·펫·동료 셋. 주인공은 아직 초상화가 없으니(스펙 5.3) 이름 글자로, 펫은 `PixelIcon.egg`, 동료는 잠금.

- [ ] **Step 1: `party_row.dart`를 통째로 다시 쓴다**

지금 파일은 Material `Theme`·`Icons.add`를 쓰는 스텁이다. 픽셀 UI로 바꾼다.

```dart
// flutter/lib/ui/party_row.dart — 통째로 이 내용으로
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/skill.dart';
import 'hud/game_popup.dart';
import 'hud/pixel_icons.dart';
import 'hud/pixel_ui.dart';
import 'pet_panel.dart';

/// 우하단 초상 줄 — AUTO · 주인공 · 펫 · 동료.
///
/// 같이 싸우는 것들이 한 줄에 선다. 초상을 누르면 그 대상의 창이 열린다.
/// 다음 계획(팝업 골격)에서 이 줄이 팝업 왼쪽에도 붙는다 — 그래서 위젯으로 뺐다.
class PartyPortraits extends ConsumerWidget {
  const PartyPortraits({super.key});

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
        _Portrait(label: '주인공', child: const PixelText('나', size: 12, color: PixelPalette.gold), onTap: null),
        const SizedBox(width: 4),
        _Portrait(
          label: state.pets.active?.grade.label ?? '펫',
          child: PixelIconView(PixelIcon.egg, size: 16),
          alert: state.hatchery.hasReady,
          onTap: () => showGamePopup(context, title: '펫', child: const PetPanel()),
        ),
        const SizedBox(width: 4),
        _Portrait(label: '동료', child: const PixelText('🔒', size: 10), locked: true, onTap: null),
      ],
    );
  }
}

/// 초상 한 칸. 아직 그림이 없어 글자나 아이콘으로 채운다 — 초상화는 스펙 5.3.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.label, required this.child, required this.onTap, this.alert = false, this.locked = false});

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool alert;
  final bool locked;

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
                  child: SizedBox(width: 34, height: 34, child: Center(child: child)),
                ),
                if (alert)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFE5534B), shape: BoxShape.circle)),
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
```

`PetState.active?.grade.label`이 `skill_bar.dart`의 `_PetSlot`에서 이미 쓰이는 표현이다 — 같은 걸 쓴다. `state.hatchery.hasReady`는 옛 펫 단추의 `alert` 조건 그대로다.

- [ ] **Step 2: `game_screen.dart`에서 자리를 바꾼다**

```python
# fix_party.py
import pathlib
p = pathlib.Path('flutter/lib/ui/game_screen.dart')
s = p.read_text()

old = """                children: const [
                  _PartySlotPlaceholder(),
                  SizedBox(height: 6),
                  SkillBar(),
                ],"""
new = """                children: const [
                  PartyPortraits(),
                  SizedBox(height: 6),
                  SkillBar(),
                ],"""
assert old in s, "초상 자리를 못 찾았다"
s = s.replace(old, new, 1)

# 스텁 삭제
start = s.index("/// 우하단 초상 줄 자리. Task 4가 채운다.")
end = s.index("}\n", s.index("class _PartySlotPlaceholder", start)) + 2
s = s[:start] + s[end:]

# import
if "import 'party_row.dart';" not in s:
    s = s.replace("import 'pet_panel.dart';", "import 'party_row.dart';\nimport 'pet_panel.dart';", 1)
p.write_text(s)
print("ok")
```

`PetPanel`을 `game_screen.dart`가 더는 직접 안 열면 `pet_panel.dart` import가 unused가 된다 — **지워라** (Task 3의 "Task 5가 쓴다" 예외는 `stage_select_panel`·`codex_screen`뿐이다).

- [ ] **Step 3: 테스트에 AUTO 동작을 박는다**

`flutter/test/ui/game_screen_test.dart`의 첫 테스트(`'전투 화면이 뜬다'` 류) 끝에 추가:

```dart
    // AUTO 단추는 슬롯 셋의 자동을 한 번에 끈다.
    await tester.tap(find.text('AUTO').first);
    await tester.pump();
    final skills = container.read(gameControllerProvider).skills;
    expect([0, 1, 2].map(skills.isAuto), everyElement(isFalse), reason: 'AUTO를 끄면 셋 다 꺼진다');
```

`app()` 헬퍼가 `ProviderScope(overrides: [...])`를 돌려주므로 `container` 변수가 없다. 트리 안의 아무 엘리먼트로 컨테이너를 얻는다 — `BattleArea`는 그 테스트가 이미 `find.byType`으로 찾는 위젯이다:

```dart
    final container = ProviderScope.containerOf(tester.element(find.byType(BattleArea)));
```

이 줄을 `skills`를 읽는 줄 **앞에** 넣어라. **도메인·컨트롤러를 바꾸지 마라.**

- [ ] **Step 4: 테스트·캡처**

```bash
cd flutter && flutter analyze lib/ui/party_row.dart lib/ui/game_screen.dart 2>&1 | tail -3
flutter test 2>&1 | tail -4
flutter test test/ui/art_gallery_test.dart 2>&1 | tail -1 && ls -la build/app_screen.png
```

기대: 통과. 캡처 우하단에 `AUTO · 나 · 펫 · 동료` 네 칸 + 스킬 바.

- [ ] **Step 5: 커밋**

```bash
git add flutter/lib/ui/party_row.dart flutter/lib/ui/game_screen.dart flutter/test/ui/game_screen_test.dart
git commit -m "feat(flutter): 우하단 초상 줄 — AUTO · 주인공 · 펫 · 동료

같이 싸우는 것들이 한 줄에 선다. AUTO는 스킬 슬롯 셋의 자동을 한 번에
켜고 끈다. 초상을 누르면 그 대상의 창이 열린다 — 펫은 지금, 동료는 잠금.

Material 스텁이던 party_row를 픽셀 UI로 다시 썼다. 다음 계획에서
이 줄이 팝업 왼쪽에도 붙는다.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: 메뉴 그리드와 콘텐츠 2탭

**Files:**
- Create: `flutter/lib/ui/hud/menu_grid.dart`
- Create: `flutter/lib/ui/contents_panel.dart`
- Modify: `flutter/lib/ui/game_screen.dart` (우상단 `콘텐츠`·`메뉴` onTap)

**Interfaces:**
- Consumes: Task 2 아이콘, Task 3의 `_showComingSoon`·`HudButton.locked`, 기존 `DungeonPanel`·`StageSelectPanel`·`CodexTab`·`AttendancePanel`·`DailyPanel`
- Produces: `showMenuGrid(context)`, `ContentsPanel`. 메뉴 그리드가 진입점 20개의 집이다 — 새 화면은 여기 칸 하나

- [ ] **Step 1: 콘텐츠 2탭**

```dart
// flutter/lib/ui/contents_panel.dart — 신규
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
```

**주의**: `StageSelectPanel`·`DungeonPanel`이 `ListView`를 반환한다(확인함). 바깥 `ListView` 안에 넣으면 높이가 무한대라 깨진다. `_Unscrolled`만으로는 부족하다 — **각 패널의 `ListView`에 `shrinkWrap: true, physics: const NeverScrollableScrollPhysics()`가 필요하다.** 두 패널 파일을 열어 `return ListView(` 를 `return ListView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),` 로 바꿔라. 이 두 패널은 이제 콘텐츠 안에서만 쓰이므로 독립 스크롤이 필요 없다. 이 변경도 이 태스크에 포함한다.

- [ ] **Step 2: 메뉴 그리드**

```dart
// flutter/lib/ui/hud/menu_grid.dart — 신규
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
```

`epochDayOf`는 `domain/attendance.dart:53`, `anyDailyReady`는 `domain/daily.dart:99`에 있다(확인함). 위 import 목록이 맞다.

- [ ] **Step 3: 우상단을 진짜 팝업에 잇는다**

```python
# fix_topright.py
import pathlib
p = pathlib.Path('flutter/lib/ui/game_screen.dart')
s = p.read_text()

old = """                    // Task 5가 던전/도전 2탭 팝업으로 바꾼다. 지금은 던전만.
                    onTap: () => showGamePopup(context, title: '던전', child: const DungeonPanel()),"""
new = """                    onTap: () => showGamePopup(context, title: '콘텐츠', child: const ContentsPanel()),"""
assert old in s, "콘텐츠 onTap을 못 찾았다"
s = s.replace(old, new, 1)

old2 = """                  // Task 5가 메뉴 그리드로 바꾼다.
                  HudButton(label: '메뉴', icon: PixelIcon.menu, onTap: () => _showComingSoon(context, '메뉴')),"""
new2 = """                  HudButton(label: '메뉴', icon: PixelIcon.menu, onTap: () => showMenuGrid(context)),"""
assert old2 in s, "메뉴 onTap을 못 찾았다"
s = s.replace(old2, new2, 1)

s = s.replace("import 'codex_screen.dart';\n", "import 'contents_panel.dart';\n", 1)
s = s.replace("import 'hud/game_popup.dart';\n", "import 'hud/game_popup.dart';\nimport 'hud/menu_grid.dart';\n", 1)
p.write_text(s)
print("ok")
```

이제 `game_screen.dart`에서 `DungeonPanel`·`StageSelectPanel`·`CodexTab`·`AttendancePanel`·`DailyPanel`을 **어디서 쓰는지** `flutter analyze`로 본다. 출석·오늘은 좌측 아래에서 아직 쓴다. 던전·층이동·도감은 이제 콘텐츠/메뉴 안에서만 쓰이므로 unused import를 **지운다.**

- [ ] **Step 4: 테스트를 더한다**

`game_screen_test.dart`에 테스트 하나:

```dart
  testWidgets('메뉴 그리드가 열리고 콘텐츠에 던전·층 이동이 있다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('메뉴').first);
    await tester.pumpAndSettle();
    for (final label in ['캐릭터', '강화', '영지', '동료', '랭킹', '도움말', '설정']) {
      expect(find.text(label), findsWidgets, reason: '$label 칸 (잠금이라도 자리는 있다)');
    }
    expect(find.textContaining('도감'), findsWidgets);

    await tester.tap(find.text('콘텐츠').first);
    await tester.pumpAndSettle();
    expect(find.text('던전'), findsWidgets);
    expect(find.text('도전'), findsWidgets);
    expect(find.text('층 이동'), findsWidgets, reason: '층 이동이 던전 탭 안에 있다');
  });
```

- [ ] **Step 5: 테스트·캡처**

```bash
cd flutter && flutter analyze lib/ui/ 2>&1 | tail -4
flutter test 2>&1 | tail -4
```

기대: 통과. `flutter analyze`에 unused import가 남아 있으면 지운다.

- [ ] **Step 6: 커밋**

```bash
git add flutter/lib/ui/hud/menu_grid.dart flutter/lib/ui/contents_panel.dart flutter/lib/ui/game_screen.dart flutter/lib/ui/dungeon_panel.dart flutter/lib/ui/stage_select_panel.dart flutter/test/ui/game_screen_test.dart
git commit -m "feat(flutter): 메뉴 그리드와 콘텐츠 2탭 — 진입점 전부가 한 장에

우상단 ≡가 4열 그리드를 연다. 레퍼런스처럼 접지 않고 펼친다 —
새 화면이 늘면 칸을 하나 더 붙이면 된다. 없는 것은 잠금.

콘텐츠는 던전/도전 2탭. 층 이동은 성격이 바깥으로라 던전 탭에 같이 뒀다.
도전(아레나)은 3등급이라 비어 있다.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: HUD를 셋으로 가른다

**Files:**
- Modify: `flutter/lib/ui/hud/battle_hud.dart` (`BattleHud` → `ProfileBadge` + `StageStatus` + `MonsterLine`)
- Modify: `flutter/lib/ui/battle_area.dart` (`BattleHud` 호출부)

**Interfaces:**
- Consumes: 지금 `BattleHud`의 세 덩어리(상단 Row / 시간·진행 게이지 / 하단 몬스터 줄)
- Produces: 좌상단 `ProfileBadge`, 상단 중앙 `StageStatus`, 무대 하단 `MonsterLine`. `BattleArea`가 셋을 각자 자리에 놓는다

**왜 가르는가**: 지금 `BattleHud`는 세로 화면용으로 위에서 아래로 쌓는다(상단 Row → 게이지 → Spacer → 하단 줄). 가로에서는 좌상단과 상단 중앙이 **옆으로** 놓여야 한다. 한 `Column`으로는 안 된다.

- [ ] **Step 1: 지금 구조를 확인한다**

```bash
grep -n "class BattleHud\|// ── \|_PowerBadge\|_progressLabel" flutter/lib/ui/hud/battle_hud.dart
grep -n "BattleHud(" flutter/lib/ui/battle_area.dart
```

기대: `BattleHud.build`가 `Column` 하나에 `// ── 상단`, `// ── 층에 남은 시간`, `// ── 스테이지 진행 게이지`, `Spacer`, `// ── 하단 한 줄`을 쌓는다. `battle_area.dart`가 `Positioned.fill(child: IgnorePointer(child: BattleHud(...)))`로 얹는다.

- [ ] **Step 2: 세 위젯으로 가른다**

`battle_hud.dart`의 `BattleHud` 클래스를 지우고 셋을 만든다. `_PowerBadge`·`_SwordIcon`·`_progressLabel`은 그대로 둔다.

```dart
// battle_hud.dart의 BattleHud 클래스를 아래 셋으로 바꾼다. import·_PowerBadge·_SwordIcon·_progressLabel은 그대로.

/// 좌상단 · 나에 관한 것. 전투력 · 골드 · 젬.
/// Lv·이름은 계정 시스템(3등급)이 생기면 붙는다.
class ProfileBadge extends StatelessWidget {
  const ProfileBadge({super.key, required this.state, required this.config});

  final GameState state;
  final BalanceConfig config;

  @override
  Widget build(BuildContext context) {
    final stats = state.statsWith(config);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PowerBadge(power: stats.dps(config)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CurrencyChip(amount: formatNumber(state.gold), color: PixelPalette.gold),
            const SizedBox(width: 5),
            const CurrencyChip(amount: '0', color: PixelPalette.gem, gem: true),
          ],
        ),
      ],
    );
  }
}

/// 상단 중앙 · 지금 상태. 층 이름 · 제한 시간 막대 · 남은 수.
/// 던전에 들어가 있으면 같은 자리에 던전 진행을 보여 준다.
class StageStatus extends StatelessWidget {
  const StageStatus({super.key, required this.state, required this.config, required this.regionName});

  final GameState state;
  final BalanceConfig config;
  final String regionName;

  @override
  Widget build(BuildContext context) {
    final run = state.dungeon.run;
    final progress = run != null
        ? (1 - run.wavesLeft / config.dungeonWaves).clamp(0.0, 1.0)
        : state.isBoss
            ? 1.0
            : (state.killsOnStage / config.killsPerStage).clamp(0.0, 1.0);
    final accent = run != null
        ? PixelPalette.gem
        : state.isBoss
            ? PixelPalette.boss
            : PixelPalette.gold;

    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelPanel(
            border: run == null ? PixelPalette.ink : PixelPalette.gem,
            child: PixelText(
              run == null ? '$regionName ${state.stage}층' : '${run.type.label} ${run.floor}층',
              size: 11,
              color: run == null ? PixelPalette.textDim : PixelPalette.gem,
            ),
          ),
          const SizedBox(height: 4),
          if (run == null && !state.isBoss)
            Row(
              children: [
                Expanded(
                  child: PixelGauge(
                    value: state.stageTimeRatio(config),
                    color: state.stageTimeRatio(config) > 0.25 ? PixelPalette.gold : PixelPalette.hpLow,
                    height: 7,
                  ),
                ),
                const SizedBox(width: 5),
                PixelText('${state.stageTimeLeftOr(config).ceil()}초', size: 10, color: PixelPalette.textDim),
              ],
            ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(child: PixelGauge(value: progress, color: accent, height: 10)),
              const SizedBox(width: 5),
              PixelPanel(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: run != null || state.isBoss ? accent : PixelPalette.panel,
                child: PixelText(_progressLabel(state, config, run), size: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 무대 하단 · 지금 무엇을 상대하는지와 포획 정보. 쓰러지면 그 안내.
class MonsterLine extends StatelessWidget {
  const MonsterLine({super.key, required this.state, required this.monster, required this.captureLine});

  final GameState state;
  final Monster? monster;
  final String captureLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelText(monster == null ? '몬스터' : '${monster!.name} [${monster!.element.label}]', size: 11),
            if (state.wave.length > 1) ...[
              const SizedBox(width: 6),
              PixelText('남은 ${state.wave.length}마리', size: 10, color: PixelPalette.gold),
            ],
            const SizedBox(width: 8),
            PixelText(captureLine, size: 10, color: PixelPalette.textDim),
          ],
        ),
        if (state.isDown) ...[
          const SizedBox(height: 3),
          PixelText('쓰러졌습니다 · ${state.reviveLeft.ceil()}초 뒤 일어섭니다', size: 11, color: PixelPalette.hpLow),
        ],
      ],
    );
  }
}
```

**옛 `BattleHud`와 다른 점 하나**: 층 이름이 `'$regionName 스테이지 ${state.stage}'`에서 `'$regionName ${state.stage}층'`으로 바뀐다. 테스트 `find.textContaining('스테이지 1')`이 깨진다 — Step 4에서 고친다. 기획서·백로그가 "층"이라 부르므로 화면도 그렇게 맞춘다.

- [ ] **Step 3: `battle_area.dart`가 셋을 각자 자리에 놓는다**

```python
# fix_battle_area.py
import pathlib
p = pathlib.Path('flutter/lib/ui/battle_area.dart')
s = p.read_text()
old = """        Positioned.fill(
          child: IgnorePointer(
            child: BattleHud(
              state: state,
              config: config,
              monster: monster,
              regionName: catalog.regionFor(state.stage)?.name ?? '???',
              captureLine: captureLine(),
            ),
          ),
        ),"""
new = """        // HUD 셋. 자리는 화면 지도(스펙 2절) — 좌상단 나 · 상단 중앙 지금 상태 · 무대 하단 상대.
        Positioned(left: 6, top: 6, child: IgnorePointer(child: ProfileBadge(state: state, config: config))),
        Positioned(
          left: 0, right: 0, top: 6,
          child: IgnorePointer(
            child: Center(
              child: StageStatus(state: state, config: config, regionName: catalog.regionFor(state.stage)?.name ?? '???'),
            ),
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 70,
          child: IgnorePointer(
            child: Center(child: MonsterLine(state: state, monster: monster, captureLine: captureLine())),
          ),
        ),"""
assert old in s, "BattleHud 호출부를 못 찾았다"
p.write_text(s.replace(old, new, 1))
print("ok")
```

`bottom: 70`은 하단 5칸(약 60px) 바로 위다. 캡처에서 겹치면 조정한다.

- [ ] **Step 4: 테스트를 맞춘다**

```bash
grep -rn "스테이지 1\|BattleHud" flutter/test/
```

`find.textContaining('스테이지 1')` → `find.textContaining('1층')`. `BattleHud`를 직접 찾는 테스트가 있으면 `StageStatus`로.

- [ ] **Step 5: 테스트·캡처**

```bash
cd flutter && flutter analyze lib/ui/hud/battle_hud.dart lib/ui/battle_area.dart 2>&1 | tail -3
flutter test 2>&1 | tail -4
flutter test test/ui/art_gallery_test.dart 2>&1 | tail -1 && ls -la build/app_screen.png
```

캡처를 열어 **좌상단에 전투력·골드·젬, 상단 중앙에 층·시간·진행, 무대 하단에 몬스터 이름**이 각자 자리에 있는지 본다. 하단 5칸과 `MonsterLine`이 겹치면 `bottom: 70`을 올린다.

- [ ] **Step 6: 커밋**

```bash
git add flutter/lib/ui/hud/battle_hud.dart flutter/lib/ui/battle_area.dart flutter/test/
git commit -m "feat(flutter): HUD를 셋으로 — 좌상단 나 · 상단 중앙 지금 상태 · 무대 하단 상대

세로 화면용 Column 하나였다. 가로에서는 좌상단과 상단 중앙이 옆으로
놓여야 해서 한 Column으로는 안 된다.

층 이름을 '스테이지 N'에서 'N층'으로. 기획서와 백로그가 층이라 부른다.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: 캡처·문서·정합

**Files:**
- Modify: `docs/BACKLOG.md` (D4-1 완료, A4 스킬 창 항목 상태)
- Modify: `docs/superpowers/specs/2026-09-05-screen-map-design.md` §2 (실제와 다른 곳)

- [ ] **Step 1: 최종 캡처를 다시 만들고 일곱 자리를 센다**

```bash
cd flutter && flutter test test/ui/art_gallery_test.dart 2>&1 | tail -1
python3 -c "
from PIL import Image
im = Image.open('build/app_screen.png').convert('RGB'); w,h = im.size
col = [im.getpixel((w-2, y)) for y in range(0, h, h//8)]
print('우측 띠 남았나:', any(abs(r-18)<4 and abs(g-22)<4 and abs(b-26)<4 for r,g,b in col))
"
```

캡처를 열어 아래 표대로 있는지 하나씩 확인해 리포트에 ✓/✗를 적는다:

| 자리 | 있어야 하는 것 |
|---|---|
| 좌상단 | 전투력 뱃지 · 골드 · 젬 |
| 좌측 | 퀘스트 카드 |
| 좌측 아래 | 출석 · 오늘 |
| 좌하단 | 광고(잠금) |
| 상단 중앙 | 층 이름 · 시간 막대 · 진행 |
| 우상단 | 콘텐츠 · 소환(잠금) · 상점(잠금) · 메뉴 |
| 하단 중앙 | 장비 · 스킬 · 대장간(큼) · 무기(잠금) · 성장 |
| 우하단 | AUTO · 나 · 펫 · 동료(잠금) · 스킬 3칸 |

**겹치는 곳이 있으면** 그 자리의 `Positioned` 값을 조정하고 리포트에 적는다. 캡처 크기는 `844×390` 논리 픽셀이다 — 실기기 비율이다.

- [ ] **Step 2: 백로그**

```python
# fix_backlog.py
import pathlib
p = pathlib.Path('docs/BACKLOG.md')
s = p.read_text()
old = "### D4-1. 가로 화면의 우측 띠 · S — **다음 계획(자리 재배치)에서**"
new = "### D4-1. 가로 화면의 우측 띠 · S — **완료 (2026-09-05)** — maxWidth 480을 풀었다"
assert old in s, "D4-1을 못 찾았다"
p.write_text(s.replace(old, new, 1))
print("ok")
```

- [ ] **Step 3: 스펙 §2 표를 실제와 맞춘다**

스펙 2절 표가 `Lv 뱃지 · 이름`과 `▶▶배속`을 적었는데 이번에 안 넣었다(계정·배속은 3등급). 표 옆에 한 줄:

```python
# fix_spec.py
import pathlib
p = pathlib.Path('docs/superpowers/specs/2026-09-05-screen-map-design.md')
s = p.read_text()
old = "**하단 5칸이 레퍼런스와 정확히 일치한다**"
new = """**2026-09-05 구현 뒤 실제와 다른 곳**: 좌상단의 `Lv`·이름은 계정 시스템(3등급 7번)이 없어 전투력·골드·젬만 있다.
상단 중앙의 `▶▶배속`은 9절 미결이라 없다. 소환·상점·전용무기·동료·광고는 자리만 있고 잠겨 있다.

**하단 5칸이 레퍼런스와 정확히 일치한다**"""
assert old in s, "스펙 2절 문장을 못 찾았다"
p.write_text(s.replace(old, new, 1))
print("ok")
```

- [ ] **Step 4: 전체 테스트**

```bash
cd flutter && flutter test 2>&1 | tail -3 && flutter analyze 2>&1 | tail -3
```

기대: 전부 통과, analyze 깨끗.

- [ ] **Step 5: 커밋**

```bash
git add docs/
git commit -m "docs: 자리 재배치 완료 반영 — D4-1 닫고 스펙 2절을 실제와 맞춤

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## 이 계획이 하지 않는 것

- **팝업 안쪽.** 좌측 초상 열·2단·일괄 버튼은 다음 계획(팝업 골격)이다. `game_popup.dart`는 `HudButton` 옵션 둘만 더한다
- **새 기능.** 소환·상점·전용무기·동료·영지·랭킹·캐릭터·강화·설정·도움말·도전·배속·광고 — 전부 잠금 단추다. 각자 3등급 스펙이 있다
- **초상화.** 주인공 초상은 '나' 글자다. 초상화는 스펙 5.3(컷신)과 같이 온다
- **`Lv`·이름.** 계정 시스템(3등급 7번)

## 알려진 위험

| 위험 | 어디서 | 대응 |
|---|---|---|
| `ListView` 안에 `ListView` (콘텐츠 던전 탭) | Task 5 Step 1 | `shrinkWrap + NeverScrollable`을 두 패널에 넣는다. 안 넣으면 높이 무한대로 깨진다 |
| `🔒` 이모지가 픽셀 글꼴에 없다 | Task 3·4 캡처 | `'L'` 글자로 바꾼다 |
| 844×390에서 자리가 겹친다 | Task 7 | `Positioned` 값 조정. 특히 `MonsterLine`(bottom 70)과 하단 5칸, 좌측 아래 2칸과 좌하단 광고 |
| `find.text('성장')` 등이 팝업 안 글자까지 잡는다 | Task 3 Step 5 | `findsWidgets`라 통과. `findsOneWidget`인 곳만 고친다 |
| `SnackBar`가 `Scaffold` 밖에서 호출된다 | Task 5 `_MenuGrid._soon` | `showDialog` 안이라 `ScaffoldMessenger.of(context)`가 루트를 찾는다. 안 되면 `pop()` 뒤 호출 순서를 바꾼다 |
