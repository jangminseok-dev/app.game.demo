# 소환 2 — 연출과 승급 표시 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 소환을 누른 순간 소환진이 그려지고 빛기둥이 등급 색으로 올라오게 하고, 중복이 승급으로 들어간 것을 화면에 보이게 한다.

**Architecture:** 연출은 `lib/ui/hud/summon_flourish.dart` 한 파일이다 — `AnimationController` 하나가 0~1을 흐르고 구간마다 다른 것을 그린다(어둡게 → 소환진 → 빛기둥 → 결과). 그리기는 `CustomPainter` 둘(`_CirclePainter`·`_PillarPainter`)이 맡는다. 승급 표시는 도메인이 결과에 `before`/`after`를 실어 주면 화면이 `뿔 ★4 → ★5`로 읽는 것뿐이다.

**Tech Stack:** Flutter · `AnimationController` + `SingleTickerProviderStateMixin`(이 저장소가 `battle_area.dart`·`game_screen.dart`에서 쓰는 방식) · `CustomPainter`(`battle_hud.dart`의 `_SwordIcon`, `pixel_ui.dart`의 `_BevelPainter`와 같은 방식)

**Spec:** `docs/superpowers/specs/2026-09-05-summon-design.md` 7절(연출). 4.8절(기존 획득 연출)도 읽어라 — 연출의 뒷부분이 그것이다.

## Global Constraints

- **정령은 이 계획에 없다.** 스펙 7.3(정령 등장 컷신)은 계획 3이다. 소환 화면의 `정령` 탭은 계속 잠긴 채 '준비 중' 한 줄이다.
- **밸런스 숫자를 건드리지 마라.** 확률·성급 상한·천장·수급량은 2026-09-05에 조정을 끝냈다(`balance_config.dart`).
- **설정의 "소환 연출 생략"은 이 계획에 없다.** 3등급 1번(메뉴·설정)에서 만든다(스펙 7.2).
- **백엔드는 건드리지 않는다.**
- 화면은 가로 고정. 세로용 분기를 만들지 마라.
- 레퍼런스 게임의 이름·고유명을 코드·UI·자산 이름에 절대 넣지 마라.
- 주석·커밋 메시지·UI 문구는 **한국어**. 주변 코드의 말투(단정형, 짧은 문장)를 따른다.
- Dart lint `sort_child_properties_last` 가 켜져 있다 — `child:` 를 마지막 인자로 유지하라.
- 각 태스크 끝에서 `cd flutter && flutter analyze` 가 **0건**(info 포함), `flutter test` 가 전부 통과. **시작 기준은 296개 통과 · analyze 0건.**
- 커밋 메시지 끝에 두 줄:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th
  ```

---

## 파일 구조

| 파일 | 책임 | 이 계획에서 |
|---|---|---|
| `flutter/lib/domain/summon.dart` | 소환 규칙과 결과 | `SummonResult` 에 `before`/`after`, `upgraded` 를 게터로, 결과 한 줄 문구 |
| `flutter/lib/ui/hud/summon_flourish.dart` | 소환 연출 한 벌 | **신규** — 소환진·빛기둥·단계 진행·건너뛰기 |
| `flutter/lib/ui/summon_panel.dart` | 소환 화면 | 결과 줄이 승급을 보여주고, 연출을 부른다 |
| `docs/superpowers/specs/2026-09-05-summon-design.md` · `docs/BACKLOG.md` | 문서 | 마지막 태스크 |

**왜 `hud/` 아래 새 파일인가**: 연출은 소환 화면만의 것이 아니다 — 계획 3의 정령 등장 컷신이 같은 그리기(어둡게·빛)를 쓴다. `summon_panel.dart` 안에 두면 그때 꺼내야 한다. 다만 **지금 정령용 추상화를 만들지는 마라**(YAGNI). 파일만 분리해 두면 된다.

---

### Task 1: 승급이 화면에 보인다

전체 리뷰가 잡은 것이다. 지금 화면은 **굴려 나온 성급**을 보여준다 — 뿔 ★4를 가진 채 뿔 ★1이 나오면 화면은 `[뿔 ★1]`이라 하는데 실제로는 ★5가 된다. "헛도는 소환이 없다"가 이 시스템의 핵심 약속인데(스펙 1절·10절) 유저가 그걸 한 번도 못 본다.

**Files:**
- Modify: `flutter/lib/domain/summon.dart` (`SummonResult`, `summonRelics`, 새 함수 `summonResultLine`)
- Modify: `flutter/lib/ui/summon_panel.dart` (결과 목록과 `_summon` 의 `lines`)
- Test: `flutter/test/domain/summon_test.dart`, `flutter/test/ui/game_screen_test.dart`

**Interfaces:**
- Produces:
  - `SummonResult({required RelicSlot slot, required int stars, required bool byPity, int before = 0, int after = 0})` — `bool get upgraded => before > 0;`
  - `String summonResultLine(SummonResult r)` — 승급이면 `'뿔 ★4 → ★5'`, 아니면 `'뿔 ★2'`
- Task 2의 연출이 같은 `summonResultLine` 을 쓴다.

**`before`/`after` 를 채우는 곳은 `summonRelics` 하나다.** `rollRelic` 은 굴리기만 하므로 둘 다 기본값 0으로 둔다 — 그 사실을 주석에 적어라.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`flutter/test/domain/summon_test.dart` 의 `group('승급', ...)` 안에 더한다.

```dart
    test('결과가 승급 전후를 싣는다', () {
      // 네 칸을 다 ★3으로 두면 어느 부위가 나오든 승급이다.
      // 한 칸만 씨앗으로 두면 그 부위가 10연차에 안 나올 확률이 5.6%라 씨앗에 기댄 테스트가 된다.
      const start = SummonState(stones: 10000, relics: {
        RelicSlot.horn: 3, RelicSlot.tail: 3, RelicSlot.wing: 3, RelicSlot.scale: 3,
      });
      final (_, results) = summonRelics(start, Random(1), config, count: 10);
      expect(results.first.before, greaterThanOrEqualTo(3));
      expect(results.first.after, greaterThan(results.first.before));
      expect(results.first.upgraded, isTrue);
    });

    test('처음 나온 부위는 승급이 아니다', () {
      final (_, results) = summonRelics(
          const SummonState(stones: 10000), Random(2), config, count: 1);
      expect(results.single.before, 0);
      expect(results.single.after, results.single.stars);
      expect(results.single.upgraded, isFalse);
    });

    test('한 배치에서 같은 부위가 두 번 나오면 두 번째의 before가 첫 번째의 after다', () {
      final (_, results) = summonRelics(
          const SummonState(stones: 10000), Random(4), config, count: 10);
      final bySlot = <RelicSlot, List<SummonResult>>{};
      for (final r in results) {
        bySlot.putIfAbsent(r.slot, () => []).add(r);
      }
      final repeated = bySlot.values.firstWhere((v) => v.length >= 2);
      expect(repeated[1].before, repeated[0].after);
    });

    test('결과 한 줄이 승급을 보여 준다', () {
      const fresh = SummonResult(slot: RelicSlot.horn, stars: 2, byPity: false, before: 0, after: 2);
      const up = SummonResult(slot: RelicSlot.wing, stars: 1, byPity: false, before: 4, after: 5);
      expect(summonResultLine(fresh), '뿔 ★2');
      expect(summonResultLine(up), '날개 ★4 → ★5',
          reason: '굴린 값(★1)이 아니라 오른 값을 보여야 한다 — 헛도는 소환이 없다는 약속이 여기서 보인다');
    });
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/domain/summon_test.dart 2>&1 | tail -15
```

기대: `before`·`after`·`summonResultLine` 이 없어 컴파일 실패. 통과하면 멈추고 보고하라.

- [ ] **Step 3: `SummonResult` 를 고친다**

`flutter/lib/domain/summon.dart`:

```dart
/// 소환 한 건의 결과.
class SummonResult {
  const SummonResult({
    required this.slot,
    required this.stars,
    required this.byPity,
    this.before = 0,
    this.after = 0,
  });

  final RelicSlot slot;

  /// 굴려 나온 성급(1~maxRolledStars). 실제로 오른 값은 [after] 다.
  final int stars;

  /// 천장으로 확정된 것인지.
  final bool byPity;

  /// 이 소환 **전** 그 부위의 성급. 0이면 처음 나온 부위다.
  ///
  /// [rollRelic] 은 굴리기만 하므로 이 값을 안 채운다. 채우는 곳은 [summonRelics] 하나다.
  final int before;

  /// 승급까지 끝난 **뒤**의 성급. 화면은 이 값을 보여 준다.
  final int after;

  /// 이미 갖고 있던 부위라 승급으로 들어갔는지.
  bool get upgraded => before > 0;
}
```

`summonRelics` 안의 결과 만드는 곳을 바꾼다:

```dart
    final current = relics[rolled.slot] ?? 0;
    final merged = mergeStars(current: current, rolled: rolled.stars);
    relics[rolled.slot] = merged;
    results.add(SummonResult(
      slot: rolled.slot,
      stars: rolled.stars,
      byPity: rolled.byPity,
      before: current,
      after: merged,
    ));
```

**`upgraded: current > 0` 인자는 지운다** — 이제 게터다.

파일 끝에 문구 함수를 더한다:

```dart
/// 결과 한 줄. 승급이면 어디서 어디로 갔는지 보여 준다.
///
/// 굴린 값을 보여 주면 뿔 ★4에 ★1이 나왔을 때 화면이 `뿔 ★1`이라 말한다 —
/// 실제로는 ★5가 되는데도. "헛도는 소환이 없다"는 이 시스템의 약속(1절·10절)이
/// 화면에서 한 번도 안 보이던 자리다.
String summonResultLine(SummonResult r) =>
    r.upgraded ? '${r.slot.label} ★${r.before} → ★${r.after}' : '${r.slot.label} ★${r.after}';
```

- [ ] **Step 4: 화면이 그 값을 읽게 한다**

`flutter/lib/ui/summon_panel.dart` 두 곳:

```dart
      lines: [for (final r in results) summonResultLine(r)],
```

```dart
                            child: PixelText('[${summonResultLine(r)}]', size: 11),
```

- [ ] **Step 5: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, **300 통과**(296 + 새 테스트 4).

`flutter/test/ui/game_screen_test.dart` 는 **손대지 않는다.** 화면이 `summonResultLine` 을 부르는지는 analyze와 리뷰가 확인한다 — 실제로 소환을 누르려면 소환석이 필요한데 새 게임은 0이고, 상태를 주입하는 장치가 이 저장소에 아직 없다.

- [ ] **Step 6: 커밋**

```bash
git add flutter/lib flutter/test/domain/summon_test.dart
git commit -m "feat(flutter): 승급이 화면에 보인다 — 뿔 ★4 → ★5

지금까지 화면은 굴려 나온 성급을 보여 줬다. 뿔 ★4에 ★1이 나오면
'뿔 ★1'이라 말했지만 실제로는 ★5가 됐다. '헛도는 소환이 없다'는
이 시스템의 약속이 화면에서 한 번도 안 보였다.

결과에 before/after를 실어 어디서 어디로 갔는지 보여 준다.
upgraded는 before > 0에서 나오는 게터가 됐다 — 안 쓰이던 필드였다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 2: 소환 연출

스펙 7.1·7.2. **심장은 결과가 아니라 빛기둥이다** — 결과를 보기 전에 색으로 먼저 안다.

**Files:**
- Create: `flutter/lib/ui/hud/summon_flourish.dart`
- Modify: `flutter/lib/ui/summon_panel.dart` (`_summon` 이 이걸 부른다)
- Test: `flutter/test/ui/summon_flourish_test.dart` (신규)

**Interfaces:**
- Consumes: Task 1의 `SummonResult.after`·`summonResultLine`, 기존 `PixelPalette`·`PixelText`·`PixelPanel`
- Produces:
  - `Future<void> showSummonFlourish(BuildContext context, List<SummonResult> results)`
  - `Color pillarColorFor(int topStars)` — 순수 함수라 테스트가 쉽다

**등급 색** (스펙 7.1의 흰 → 파랑 → 보라 → 금):

| 최고 성급 | 색 |
|---|---|
| ★1~2 | `PixelPalette.text` (0xFFF6ECDA, 흰) |
| ★3 | `PixelPalette.gem` (0xFF63C7FF, 파랑) |
| ★4 | `Color(0xFFB388FF)` (보라 — `EquipGrade.epic` 과 같은 값이다. 장비를 import하지 말고 값을 적고 주석을 남겨라) |
| ★5 이상 | `PixelPalette.gold` (0xFFFFC24A, 금) |

**색을 정하는 기준은 `after` 가 아니라 `stars`(굴린 값)다.** 기둥은 "무엇이 나왔나"를 알리는 것이고 승급은 그 뒤에 일어난다. 10연차면 **굴린 값 중 최고**로 기둥 하나를 올린다(스펙 7.2 — 열 번 반복하면 지겹다).

**시간표** (총 1.6초):

| 구간 | t | 무엇 |
|---|---|---|
| 어두워짐 | 0.00~0.15 | 배경이 검게 |
| 소환진 | 0.15~0.45 | 바닥 원이 시계방향으로 차오르고 룬 8개가 켜진다 |
| 빛기둥 | 0.45~0.80 | 기둥이 아래에서 위로 자란다 |
| 결과 | 0.80~1.00 | 결과 줄과 "빈 곳을 터치하세요" |

**건너뛰기**: 아무 데나 탭하면 `controller.value = 1.0`. 이미 1.0이면 닫는다. 즉 **한 번 탭 = 건너뛰기, 두 번째 탭 = 닫기**.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`flutter/test/ui/summon_flourish_test.dart` 를 만든다. 다른 UI 테스트의 import 스타일을 따라라(패키지 이름은 `flutter/pubspec.yaml` 의 `name:`).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/summon.dart';
import 'package:idle_fantasy/ui/hud/pixel_ui.dart';
import 'package:idle_fantasy/ui/hud/summon_flourish.dart';

void main() {
  group('기둥 색', () {
    test('굴린 성급이 색을 정한다 — 흰 · 파랑 · 보라 · 금', () {
      expect(pillarColorFor(1), PixelPalette.text);
      expect(pillarColorFor(2), PixelPalette.text);
      expect(pillarColorFor(3), PixelPalette.gem);
      expect(pillarColorFor(4), const Color(0xFFB388FF));
      expect(pillarColorFor(5), PixelPalette.gold);
    });

    test('범위를 벗어나도 안 터진다', () {
      expect(pillarColorFor(0), PixelPalette.text);
      expect(pillarColorFor(99), PixelPalette.gold);
    });
  });

  group('연출', () {
    Future<void> open(WidgetTester tester, List<SummonResult> results) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSummonFlourish(context, results),
            child: const Text('열기'),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pump();
    }

    testWidgets('끝까지 두면 결과가 뜬다', (tester) async {
      await open(tester, const [
        SummonResult(slot: RelicSlot.horn, stars: 5, byPity: false, before: 0, after: 5),
      ]);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.text('뿔 ★5'), findsWidgets);
      expect(find.text('빈 곳을 터치하세요'), findsWidgets);
    });

    testWidgets('탭하면 건너뛰고 결과로 간다', (tester) async {
      await open(tester, const [
        SummonResult(slot: RelicSlot.wing, stars: 1, byPity: false, before: 4, after: 5),
      ]);
      // 아직 연출 중이라 결과가 없다.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('날개 ★4 → ★5'), findsNothing);

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(find.text('날개 ★4 → ★5'), findsWidgets, reason: '건너뛰면 즉시 결과다');
    });

    testWidgets('10연차는 기둥 하나에 결과 열 줄이다', (tester) async {
      final results = [
        for (var i = 0; i < 10; i++)
          SummonResult(
            slot: RelicSlot.values[i % 4],
            stars: i == 3 ? 5 : 1,
            byPity: false,
            before: 0,
            after: i == 3 ? 5 : 1,
          ),
      ];
      await open(tester, results);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.byType(SummonResultLine), findsNWidgets(10));
    });

    testWidgets('기둥 색은 굴린 값 중 최고를 따른다', (tester) async {
      final results = [
        const SummonResult(slot: RelicSlot.horn, stars: 1, byPity: false, before: 0, after: 1),
        const SummonResult(slot: RelicSlot.tail, stars: 5, byPity: false, before: 0, after: 5),
      ];
      await open(tester, results);
      // 기둥 구간은 t=0.45부터다. 1600ms × 0.45 = 720ms — 600ms에는 아직 위젯이 없다.
      await tester.pump(const Duration(milliseconds: 800));
      final pillar = tester.widget<SummonPillar>(find.byType(SummonPillar));
      expect(pillar.color, PixelPalette.gold);
    });
  });
}
```

`SummonResultLine` 과 `SummonPillar` 는 **테스트가 잡을 수 있게 공개 위젯으로 만든다.** private으로 두면 이 테스트를 못 쓴다.

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/ui/summon_flourish_test.dart 2>&1 | tail -15
```

기대: `summon_flourish.dart` 가 없어 컴파일 실패.

- [ ] **Step 3: 그리기를 만든다**

`flutter/lib/ui/hud/summon_flourish.dart` 의 앞부분:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/summon.dart';
import 'pixel_ui.dart';

/// 소환 연출 한 벌 — 소환진 → 빛기둥 → 결과.
///
/// 심장은 결과가 아니라 **빛기둥**이다. 결과를 보기 전에 색으로 먼저 안다(스펙 7.1).
/// 금색 기둥이 올라오는 1초가 이 시스템에서 제일 좋은 1초다.
Future<void> showSummonFlourish(BuildContext context, List<SummonResult> results) {
  if (results.isEmpty) return Future<void>.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent, // 어둡게는 연출이 직접 한다 — 막이 먼저 깔리면 소환진이 안 보인다
    builder: (_) => _SummonFlourish(results: results),
  );
}

/// 굴린 성급이 기둥 색을 정한다. 승급 뒤 값이 아니다 —
/// 기둥은 "무엇이 나왔나"를 알리고 승급은 그 뒤에 일어난다.
Color pillarColorFor(int topStars) {
  if (topStars >= 5) return PixelPalette.gold;
  if (topStars == 4) return const Color(0xFFB388FF); // 보라. EquipGrade.epic과 같은 값이다
  if (topStars == 3) return PixelPalette.gem;
  return PixelPalette.text;
}
```

- [ ] **Step 4: 소환진과 기둥 위젯을 만든다**

같은 파일에 이어 쓴다.

```dart
/// 바닥의 소환진. progress 0~1 동안 원이 시계방향으로 차오르고 룬이 켜진다.
class SummonCircle extends StatelessWidget {
  const SummonCircle({super.key, required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 160, height: 56, child: CustomPaint(painter: _CirclePainter(progress, color)));
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: size.width, height: size.height);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.9);

    // 원이 위쪽 12시부터 시계방향으로 차오른다.
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, line);

    // 룬 여덟. 원이 지나간 자리만 켠다.
    for (var i = 0; i < 8; i++) {
      final t = i / 8;
      if (t > progress) continue;
      final a = -math.pi / 2 + math.pi * 2 * t;
      final p = center + Offset(math.cos(a) * size.width / 2, math.sin(a) * size.height / 2);
      canvas.drawRect(Rect.fromCenter(center: p, width: 4, height: 4), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) => old.progress != progress || old.color != color;
}

/// 등급 색으로 자라는 빛기둥. **이 연출의 심장이다.**
class SummonPillar extends StatelessWidget {
  const SummonPillar({super.key, required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 60, height: 150, child: CustomPaint(painter: _PillarPainter(progress, color)));
}

class _PillarPainter extends CustomPainter {
  const _PillarPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final h = size.height * progress;
    final rect = Rect.fromLTWH(0, size.height - h, size.width, h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(rect),
    );
    // 가운데 심지는 진하게 — 픽셀 게임이라 경계가 또렷해야 한다.
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 3, size.height - h, 6, h),
      Paint()..color = color.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_PillarPainter old) => old.progress != progress || old.color != color;
}

/// 결과 한 줄. 테스트가 개수를 세므로 공개 위젯이다.
class SummonResultLine extends StatelessWidget {
  const SummonResultLine({super.key, required this.result});

  final SummonResult result;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: PixelText(
          summonResultLine(result),
          size: 12,
          color: result.upgraded ? PixelPalette.gold : PixelPalette.text,
        ),
      );
}
```

- [ ] **Step 5: 단계 진행과 건너뛰기를 만든다**

같은 파일 끝에 쓴다.

```dart
/// 구간 [from, to] 안에서 0~1로 흐르는 값. 밖이면 0이나 1이다.
double _phase(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

class _SummonFlourish extends StatefulWidget {
  const _SummonFlourish({required this.results});

  final List<SummonResult> results;

  @override
  State<_SummonFlourish> createState() => _SummonFlourishState();
}

class _SummonFlourishState extends State<_SummonFlourish> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 한 번 탭하면 건너뛰고, 끝난 뒤 탭하면 닫는다.
  void _tap() {
    if (_c.value < 1) {
      _c.value = 1;
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 기둥 색은 **굴린 값** 중 최고를 따른다(스펙 7.2 — 10연차도 기둥은 하나다).
    final top = widget.results.map((r) => r.stars).reduce(math.max);
    final color = pillarColorFor(top);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final dim = _phase(t, 0, 0.15);
          final circle = _phase(t, 0.15, 0.45);
          final pillar = _phase(t, 0.45, 0.80);
          final shown = t >= 0.80;

          // SizedBox.expand가 없으면 Stack이 자식 크기로 줄어 '아무 데나 탭'이 빗나간다.
          return SizedBox.expand(
            child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.78 * dim),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (pillar > 0) SummonPillar(progress: pillar, color: color),
                if (circle > 0)
                  Align(
                    alignment: const Alignment(0, 0.35),
                    child: SummonCircle(progress: circle, color: color),
                  ),
                if (shown)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final r in widget.results) SummonResultLine(result: r),
                      const SizedBox(height: 20),
                      const PixelText('빈 곳을 터치하세요', size: 11, color: PixelPalette.textDim),
                    ],
                  ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }
}
```

**들여쓰기는 `dart format` 이 아니라 손으로 맞춰라** — 위 코드 조각은 `SizedBox.expand` 를 끼워 넣은 것이라 괄호 층이 하나 늘었다. 저장소가 `dart format` 을 쓰지 않으므로(`flutter analyze` 만 돈다) 주변 코드의 들여쓰기 폭에 맞춰 정리하라.

- [ ] **Step 6: 화면이 연출을 쓰게 한다**

`flutter/lib/ui/summon_panel.dart` 의 `_summon` 에서 `showRewardPopup` 을 `showSummonFlourish` 로 바꾼다.

```dart
  void _summon(int count) {
    final controller = ref.read(gameControllerProvider.notifier);
    final results = controller.summonRelic(count: count);
    if (results.isEmpty) return;
    setState(() => _results = results);
    showSummonFlourish(context, results);
  }
```

import를 정리한다 — `reward_popup.dart` 와 `pixel_icons.dart` 가 이제 안 쓰이면 `flutter analyze` 가 알려 준다. **내 변경이 만든 것만** 지워라. `showRewardPopup` 자체는 다른 화면들이 쓰므로 **지우지 마라.**

- [ ] **Step 7: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, **306 통과**(300 + 새 테스트 6).

애니메이션 테스트가 흔들리면 `pump` 시간을 늘리지 말고 **무엇이 언제 나타나는지**를 다시 계산하라 — 총 1600ms에 결과는 t=0.80(1280ms)부터다.

- [ ] **Step 8: 커밋**

```bash
git add flutter/lib flutter/test/ui/summon_flourish_test.dart
git commit -m "feat(flutter): 소환 연출 — 색이 결과를 먼저 알린다

소환진이 그려지고 빛기둥이 올라온 뒤 결과가 뜬다. 기둥 색이
굴린 등급을 미리 알린다(흰·파랑·보라·금) — 결과를 보기 전에
색으로 먼저 아는 그 1초가 이 연출의 심장이다.

10연차도 기둥은 하나다. 열 번 반복하면 지겹다. 아무 데나 탭하면
건너뛰고, 끝난 뒤 탭하면 닫힌다.

스펙 7.1·7.2.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 3: 문서

**Files:**
- Modify: `docs/superpowers/specs/2026-09-05-summon-design.md`
- Modify: `docs/BACKLOG.md`

- [ ] **Step 1: 스펙 7절에 구현 뒤 실제를 적는다**

7.2절의 마지막 항목(`- **설정에 "소환 연출 생략"** — 3등급 1번(메뉴·설정)에서 같이 만든다.`) **뒤**에 한 문단을 더한다.

```markdown
**2026-09-05 구현 뒤**: 연출은 `lib/ui/hud/summon_flourish.dart` 한 파일이고 총 **1.6초**다 —
어두워짐 0.15 · 소환진 0.15~0.45 · 빛기둥 0.45~0.80 · 결과 0.80~1.00.
**기둥 색은 굴린 성급의 최고값**을 따른다(승급 뒤 값이 아니다 — 기둥은 무엇이 나왔나를 알리고 승급은 그 뒤다).
탭 한 번이 건너뛰기, 그 뒤 탭이 닫기다. **설정의 "연출 생략"은 아직 없다** — 설정 화면이 3등급 1번이라 그때 붙인다.
```

6절(화면) 끝에도 한 줄 — 승급 표시는 연출이 아니라 화면의 약속이다:

```markdown
**2026-09-05**: 결과 줄은 굴린 성급이 아니라 **승급 결과**를 보여 준다 — `뿔 ★4 → ★5`.
굴린 값을 보여 주면 "헛도는 소환이 없다"(1절·10절)는 약속이 화면에서 한 번도 안 보인다.
```

11절(구현 순서) 끝에도 한 줄:

```markdown
**계획 2 완료 시점(2026-09-05)**: 소환 연출과 승급 표시까지. 남은 것은 정령 축(계획 3)과
주인공 용화 스프라이트(백로그 D7), 설정의 연출 생략(백로그 D8)이다.
```

- [ ] **Step 2: 백로그에 남긴다**

`docs/BACKLOG.md` 의 `### D7.` 항목 **뒤**에 붙인다.

```markdown
### D8. 소환 연출을 끌 수 있게 · XS
스펙 7.2가 "설정에 소환 연출 생략"을 요구하는데 설정 화면 자체가 3등급 1번이라 아직 없다.
지금은 탭 한 번으로 건너뛸 수 있는 것이 전부다. 설정을 만들 때 `showSummonFlourish` 앞에
한 줄로 분기하면 된다 — 연출을 건너뛰면 기존 `showRewardPopup` 을 그대로 쓴다.
```

- [ ] **Step 3: 확인하고 커밋**

```bash
cd flutter && flutter test 2>&1 | tail -2
cd .. && grep -n "2026-09-05 구현 뒤" docs/superpowers/specs/2026-09-05-summon-design.md | tail -2 && grep -n "^### D8" docs/BACKLOG.md
```

기대: 테스트 306 통과(문서만 고쳤으니 그대로), 두 문서에 새 줄이 있다.

```bash
git add docs/superpowers/specs/2026-09-05-summon-design.md docs/BACKLOG.md
git commit -m "docs: 소환 연출을 스펙과 백로그에 적는다

연출 1.6초의 구간과 기둥 색 기준(굴린 값의 최고)을 스펙 7절에
남겼다. 설정의 '연출 생략'은 설정 화면이 3등급이라 아직 없다 —
백로그 D8.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

## 이 계획이 하지 않는 것

- **정령 등장 컷신을 만들지 않는다** (스펙 7.3 — 계획 3). 정령 탭은 계속 잠긴 채다.
- **설정의 "연출 생략"을 만들지 않는다** — 설정 화면이 3등급 1번이다(백로그 D8).
- **주인공 용화 스프라이트를 안 그린다** (백로그 D7). 용화 단계는 계속 글자다.
- **밸런스 숫자를 안 건드린다.** 확률·상한·천장·수급량은 조정이 끝났다.
- **`showRewardPopup` 을 지우지 않는다.** 퀘스트·던전·출석·제작이 계속 쓴다.
- **소리를 넣지 않는다.** 이 저장소에 아직 오디오가 없다.

## 알려진 위험

| 위험 | 어디서 터지나 | 대응 |
|---|---|---|
| `barrierColor: Colors.transparent` 라 연출 전에 뒤가 다 보인다 | Task 2 Step 3 | 의도한 것이다 — 막이 먼저 깔리면 소환진이 안 보인다. 어둡게는 연출이 직접 한다 |
| 애니메이션 위젯 테스트가 `pumpAndSettle` 로 멈추지 않는다 | Task 2 Step 1 | `pumpAndSettle` 을 쓰지 마라. 이 연출은 끝나면 멈추지만, 확실한 것은 `pump(Duration)` 로 시간을 직접 넘기는 것이다 |
| 결과가 열 줄이면 화면 밖으로 넘친다 | Task 2 Step 5 | 열 줄 × 약 16px = 160px. 가로 화면 세로 390에서 들어간다. 넘치면 `Column` 을 `SingleChildScrollView` 로 감싸고 리포트에 적어라 |
| `_results` 가 화면 오른쪽 단에도 그려진다 | Task 2 Step 6 | 그대로 둔다. 연출은 한 번 보고 닫지만 오른쪽 단은 남아 다시 볼 수 있다 |
| `SummonResult` 에 필드를 더해 기존 생성자 호출이 깨진다 | Task 1 Step 3 | `before`·`after` 는 기본값이 있어 안 깨진다. `upgraded:` 인자를 넘기던 곳만 고치면 된다(`summonRelics` 한 곳) |
