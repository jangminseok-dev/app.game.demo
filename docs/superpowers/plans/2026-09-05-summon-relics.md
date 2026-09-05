# 소환 1 — 소환석과 유물 축 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 소환석이라는 재화와 유물 네 칸(뿔·꼬리·날개·비늘)을 만들고, 소환 화면에서 뽑아 주인공이 실제로 세지게 한다.

**Architecture:** 도메인에 `summon.dart` 하나를 더한다. 유물은 부위마다 성급 하나만 갖는 `Map<RelicSlot, int>` 이고 중복은 즉시 승급에 쓰인다. 스탯은 기존 `Stats.fromLevels().scaledBy().withPet()` 사슬에 `.withRelics()` 한 칸을 잇는 방식으로 붙인다. 화면은 방금 만든 팝업 골격(`GamePopup`·`PopupTwoPane`)을 그대로 쓴다.

**Tech Stack:** Flutter 3.x · Riverpod · 기존 도메인(순수 Dart, `Random` 주입) · 백엔드 FastAPI(마스터 데이터)

**Spec:** `docs/superpowers/specs/2026-09-05-summon-design.md`

## Global Constraints

- **소환석은 돈으로 살 수 없다.** 다이아 소비처에 넣지 마라. 광고 보상도 이 계획에는 없다(광고 SDK는 백로그 C3).
- **던전은 건드리지 않는다.** `DungeonType` 은 재화를 하나만 갖고 그 1:1이 설계 원칙이다(`lib/domain/dungeon.dart:6`). 소환석을 던전 보상에 붙이지 마라 — 스펙 5.3.
- **정령은 이 계획에 없다.** 소환 화면의 `정령` 탭은 자리만 두고 잠근다. 누르면 '준비 중'.
- **전용무기는 이 계획에 없다.** 하단 바의 `무기` 칸은 계속 잠겨 있다. 유물과 전용무기는 다른 축이다.
- **주인공 스프라이트는 안 바꾼다.** 용화 단계는 숫자와 글자로만 보여 준다. 그림은 아트 발주 뒤(스펙 11절).
- 화면은 가로 고정. 세로용 분기를 만들지 마라.
- 레퍼런스 게임의 이름·고유명을 코드·UI·자산 이름에 절대 넣지 마라.
- 주석·커밋 메시지·UI 문구는 **한국어**. 주변 코드의 말투(단정형, 짧은 문장)를 따른다.
- 각 태스크 끝에서 `cd flutter && flutter analyze` 가 **0건**(info 포함), `flutter test` 가 전부 통과. **시작 기준은 254개 통과 · analyze 0건.** **백엔드는 이 계획에서 건드리지 않는다.**
- Dart lint `sort_child_properties_last` 가 켜져 있다 — `child:` 를 마지막 인자로 유지하라.
- 커밋 메시지 끝에 두 줄:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th
  ```

---

## 파일 구조

| 파일 | 책임 | 이 계획에서 |
|---|---|---|
| `flutter/lib/domain/summon.dart` | 유물 네 칸·소환석·천장·용화 단계 | **신규** |
| `flutter/lib/domain/game_state.dart` | 상태 한 덩어리 | `summon` 필드 추가, `maxHeroHp` 에 비늘 |
| `flutter/lib/domain/upgrade.dart` | 레벨 → 능력치(`Stats`) | `Stats.withRelics` 추가 |
| `flutter/lib/domain/balance_config.dart` | 밸런스 계수 | 소환 계수 6개 |
| `flutter/lib/domain/save_codec.dart` | 저장 직렬화 | `summon` 한 칸 |
| `flutter/lib/domain/quest.dart` | 퀘스트와 보상 종류 | `RewardKind.summonStone` |
| `flutter/lib/domain/battle_engine.dart` | 상태 전이 | 지역 첫 진입 지급, 소환 실행 |
| `flutter/lib/app/game_controller.dart` | UI가 부르는 명령 | `summonRelic`·`summonRelicTen` |
| `flutter/lib/data/balance_codec.dart` | 서버 응답 ↔ `BalanceConfig` | 폴백 있는 읽기 6개 |
| `flutter/lib/ui/summon_panel.dart` | 소환 화면 | **신규** |
| `flutter/lib/ui/game_screen.dart` · `hud/menu_grid.dart` | 진입점 | `소환` 잠금 해제 |
| `GAME_DESIGN.md` · 스펙 · `docs/BACKLOG.md` | 문서 | 마지막 태스크 |

**왜 `summon.dart` 하나인가**: 유물·소환석·천장이 같이 바뀐다. 파일을 나누면 셋이 갈라진다. 정령이 들어올 때(계획 3) 이 파일이 커지면 그때 나눈다.

---

### Task 1: 도메인 — 소환석과 유물 상태

**Files:**
- Create: `flutter/lib/domain/summon.dart`
- Modify: `flutter/lib/domain/balance_config.dart` (계수 6개)
- Modify: `flutter/lib/domain/game_state.dart` (`summon` 필드)
- Modify: `flutter/lib/domain/save_codec.dart` (직렬화)
- Modify: `flutter/lib/data/balance_codec.dart` (서버 응답 ↔ `BalanceConfig`)
- Test: `flutter/test/domain/summon_test.dart` (신규), `flutter/test/domain/save_codec_test.dart` (추가)

**Interfaces:**
- Produces:
  - `enum RelicSlot { horn, tail, wing, scale }` — 각 값에 `label`
  - `class SummonState` — `({int stones, Map<RelicSlot,int> relics, int pityCount, int regionsRewarded})`, `starsOf`, `totalStars`, `dragonStage`, `copyWith`, `toJson`, `fromJson`, `static const empty`
  - `double relicBonus(int stars)` · `double dragonMultiplier(int stage, BalanceConfig c)`
  - `GameState.summon` · `BalanceConfig.summonCost`·`summonTenCost`·`summonPity`·`summonStonePerRegion`·`summonStonePerQuest`·`dragonStageMultiplier`
- Task 2가 굴리고, Task 3이 스탯에 걸고, Task 4가 채우고, Task 5가 그린다.

- [ ] **Step 1: 지금 구조를 확인한다**

```bash
cd flutter
grep -n "final PetState pets;\|final SkillState skills;" lib/domain/game_state.dart
grep -n "'pets'\|'skills'" lib/domain/save_codec.dart
grep -n "this.critMultiplier" lib/domain/balance_config.dart
grep -n "maxHeroHp" lib/domain/game_state.dart
```

기대: `GameState` 가 하위 상태를 `final XState x;` 로 들고, `save_codec` 이 `'x': s.x.toJson()` 으로 싣고, `fromJson` 이 `?? const {}` 폴백을 쓴다. **`summon` 도 정확히 그 모양을 따른다** — 새 방식을 발명하지 마라.

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`flutter/test/domain/summon_test.dart` 를 만든다. 기존 도메인 테스트(`test/domain/hatchery_test.dart`)의 import 스타일과 `group`/`test` 짜임새를 따라라.

```dart
import 'package:app_game_demo/domain/balance_config.dart';
import 'package:app_game_demo/domain/summon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = BalanceConfig();

  group('용화 단계', () {
    test('네 칸이 비면 0단계', () {
      expect(SummonState.empty.dragonStage, 0);
    });

    test('성급 합을 4로 나눈다 — 내림', () {
      // 합 7 → 1단계. 한 칸에 몰려 있어도 같다.
      const spread = SummonState(relics: {RelicSlot.horn: 2, RelicSlot.tail: 2, RelicSlot.wing: 2, RelicSlot.scale: 1});
      const piled = SummonState(relics: {RelicSlot.horn: 5, RelicSlot.tail: 2});
      expect(spread.totalStars, 7);
      expect(piled.totalStars, 7);
      expect(spread.dragonStage, 1);
      expect(piled.dragonStage, 1, reason: '몰아 키우든 고루 키우든 합이 같으면 같다 (스펙 3.3)');
    });

    test('네 칸이 다 ★5면 5단계', () {
      const full = SummonState(relics: {RelicSlot.horn: 5, RelicSlot.tail: 5, RelicSlot.wing: 5, RelicSlot.scale: 5});
      expect(full.dragonStage, 5);
    });
  });

  group('보정값', () {
    test('성급 0은 보정이 없다', () => expect(relicBonus(0), 0));
    test('성급이 오를수록 커진다', () {
      final values = [for (var s = 0; s <= 5; s++) relicBonus(s)];
      expect(values, [0, 0.04, 0.09, 0.15, 0.22, 0.30]);
    });
    test('용화 배수는 단계마다 곱해진다', () {
      expect(dragonMultiplier(0, config), 1.0);
      expect(dragonMultiplier(2, config), closeTo(1.06 * 1.06, 1e-9));
    });
  });

  group('저장', () {
    test('싣고 내리면 그대로다', () {
      const before = SummonState(stones: 240, relics: {RelicSlot.horn: 3, RelicSlot.scale: 1}, pityCount: 12, regionsRewarded: 2);
      final after = SummonState.fromJson(before.toJson());
      expect(after.stones, 240);
      expect(after.starsOf(RelicSlot.horn), 3);
      expect(after.starsOf(RelicSlot.scale), 1);
      expect(after.starsOf(RelicSlot.tail), 0);
      expect(after.pityCount, 12);
      expect(after.regionsRewarded, 2);
    });

    test('빈 json이면 빈 상태다 — 옛 저장이 열려야 한다', () {
      expect(SummonState.fromJson(const {}).stones, 0);
      expect(SummonState.fromJson(const {}).dragonStage, 0);
    });
  });
}
```

- [ ] **Step 3: 실패를 확인한다**

```bash
cd flutter && flutter test test/domain/summon_test.dart 2>&1 | tail -15
```

기대: `summon.dart` 가 없어 컴파일 실패. 통과하면 멈추고 보고하라.

- [ ] **Step 4: 밸런스 계수를 더한다**

`flutter/lib/domain/balance_config.dart` 의 생성자 기본값 목록 끝(마지막 필드 뒤)에 여섯 개를 더하고, 같은 순서로 `final` 선언과 `fromJson`(있다면)에도 더한다. **주변 필드가 하는 방식을 그대로 따라라** — 이 파일이 어떻게 값을 읽는지 먼저 보고 맞춰라.

```dart
    this.summonCost = 30,
    this.summonTenCost = 270,
    this.summonPity = 90,
    this.summonStonePerRegion = 150,
    this.summonStonePerQuest = 60,
    this.dragonStageMultiplier = 1.06,
```

```dart
  /// 소환 1회에 드는 소환석.
  final int summonCost;

  /// 10회 소환 값. 낱개 열 번보다 10% 싸다.
  final int summonTenCost;

  /// 이 횟수 안에 ★5가 확정으로 나온다(천장).
  final int summonPity;

  /// 지역을 처음 밟을 때 주는 소환석.
  final int summonStonePerRegion;

  /// 번호 퀘스트가 소환석을 줄 때의 양.
  final int summonStonePerQuest;

  /// 용화 한 단계가 주는 곱연산 배수.
  final double dragonStageMultiplier;
```

`flutter/lib/data/balance_codec.dart` 의 `balanceFromJson`·`balanceToJson` 에도 여섯 개를 더한다. **읽을 때는 반드시 폴백이 있는 `_d`/`_i` 를 써라** — 그 파일의 나중 필드들이 쓰는 방식이다:

```dart
      summonCost: _i(j, 'summonCost', 30),
      summonTenCost: _i(j, 'summonTenCost', 270),
      summonPity: _i(j, 'summonPity', 90),
      summonStonePerRegion: _i(j, 'summonStonePerRegion', 150),
      summonStonePerQuest: _i(j, 'summonStonePerQuest', 60),
      dragonStageMultiplier: _d(j, 'dragonStageMultiplier', 1.06),
```

폴백 값은 `BalanceConfig` 기본값과 **같아야 한다.** 서버가 아직 이 키를 안 보내므로 폴백이 실제로 쓰이는 값이다.

**백엔드는 이 계획에서 건드리지 않는다.** 밸런스 값 하나를 서버로 내보내려면 `balance.json` 말고도 `balance_dto.py`·`balance_source_port.py`·`hub/app/dtos/balance_dto.py`·`save/domain/balance/formulas.py`와 테스트 지원 파일 넷을 같이 고쳐야 한다(`grep -rln "monster_hp_base" backend --exclude-dir=.venv` 로 확인했다). 소환 계수는 아직 조정 전 초기값이라 서버에서 내려보낼 이유가 없다. 백로그 항목으로 남긴다(Task 6).

- [ ] **Step 5: `summon.dart` 를 쓴다**

```dart
import 'dart:math';

import 'balance_config.dart';

/// 유물 네 칸. GAME_DESIGN 18.2의 용 형태 곡선을 주인공에게 건다 —
/// 뿔이 나고, 꼬리가 붙고, 날개막이 생기고, 마지막에 등줄기 비늘이 돋는다.
enum RelicSlot {
  horn('뿔'),
  tail('꼬리'),
  wing('날개'),
  scale('비늘');

  const RelicSlot(this.label);

  final String label;
}

/// 소환석과 유물 네 칸.
///
/// 유물은 부위마다 성급 하나만 갖는다. 중복은 즉시 승급에 쓰이므로
/// 같은 부위를 여러 개 들고 있을 일이 없다(스펙 10절).
class SummonState {
  const SummonState({
    this.stones = 0,
    this.relics = const {},
    this.pityCount = 0,
    this.regionsRewarded = 0,
  });

  static const empty = SummonState();

  /// 유물 성급 상한.
  static const maxStars = 5;

  final int stones;

  /// 부위 → 성급(1~5). 없는 부위는 키가 없다.
  final Map<RelicSlot, int> relics;

  /// ★5 없이 뽑은 횟수. 천장에 닿으면 다음 한 번이 확정이다.
  final int pityCount;

  /// 소환석을 이미 준 지역 수. 지역을 처음 밟을 때만 주려고 센다.
  final int regionsRewarded;

  int starsOf(RelicSlot slot) => relics[slot] ?? 0;

  int get totalStars => RelicSlot.values.fold(0, (a, s) => a + starsOf(s));

  /// 용화 단계 0~5. 네 칸 성급의 합을 4로 나눈다(내림).
  ///
  /// 최솟값으로 재면 한 칸이 안 나올 때 나머지 셋이 통째로 죽는다.
  /// 무료 소환이라 뽑는 횟수가 적어 그 벽이 몇 주가 된다(스펙 3.3).
  int get dragonStage => (totalStars ~/ RelicSlot.values.length).clamp(0, maxStars);

  bool canSummon(BalanceConfig c) => stones >= c.summonCost;
  bool canSummonTen(BalanceConfig c) => stones >= c.summonTenCost;

  SummonState copyWith({
    int? stones,
    Map<RelicSlot, int>? relics,
    int? pityCount,
    int? regionsRewarded,
  }) =>
      SummonState(
        stones: stones ?? this.stones,
        relics: relics ?? this.relics,
        pityCount: pityCount ?? this.pityCount,
        regionsRewarded: regionsRewarded ?? this.regionsRewarded,
      );

  Map<String, dynamic> toJson() => {
        'stones': stones,
        'relics': {for (final e in relics.entries) e.key.name: e.value},
        'pityCount': pityCount,
        'regionsRewarded': regionsRewarded,
      };

  factory SummonState.fromJson(Map<String, dynamic> j) {
    final raw = j['relics'] as Map<String, dynamic>? ?? const {};
    return SummonState(
      stones: (j['stones'] as num? ?? 0).toInt(),
      relics: {
        for (final slot in RelicSlot.values)
          if (raw[slot.name] != null) slot: (raw[slot.name] as num).toInt(),
      },
      pityCount: (j['pityCount'] as num? ?? 0).toInt(),
      regionsRewarded: (j['regionsRewarded'] as num? ?? 0).toInt(),
    );
  }
}

/// 유물 하나가 주는 보정(0~0.30).
const _relicBonusByStars = [0.0, 0.04, 0.09, 0.15, 0.22, 0.30];

double relicBonus(int stars) => _relicBonusByStars[stars.clamp(0, SummonState.maxStars)];

/// 용화 단계가 주는 곱연산 배수.
double dragonMultiplier(int stage, BalanceConfig c) =>
    pow(c.dragonStageMultiplier, stage).toDouble();
```

- [ ] **Step 6: `GameState` 에 칸을 낸다**

`flutter/lib/domain/game_state.dart`:

1. import에 `import 'summon.dart';` 를 더한다(기존 import 줄 순서에 맞춰라).
2. 생성자 기본값에 `this.summon = SummonState.empty,` — `daily` 옆에 둔다.
3. 필드 선언:
```dart
  /// 소환석과 유물 네 칸.
  final SummonState summon;
```
4. `copyWith` 에 `SummonState? summon,` 인자와 `summon: summon ?? this.summon,` 를 더한다. **`copyWith` 의 다른 인자와 같은 자리 순서를 지켜라.**

- [ ] **Step 7: 저장에 싣는다**

`flutter/lib/domain/save_codec.dart` — `'pets'`·`'skills'` 가 실리는 방식 그대로:

```dart
      'summon': s.summon.toJson(),
```
```dart
      summon: SummonState.fromJson(j['summon'] as Map<String, dynamic>? ?? const {}),
```

`?? const {}` 폴백이 **옛 저장을 여는 유일한 장치다.** 빼면 소환 전에 저장한 사람의 데이터가 깨진다.

`flutter/test/domain/save_codec_test.dart` 에 한 케이스를 더한다:

```dart
  test('소환 상태가 저장에 실린다', () {
    const state = GameState(summon: SummonState(stones: 120, relics: {RelicSlot.wing: 4}));
    final back = decodeSave(encodeSave(state));
    expect(back.summon.stones, 120);
    expect(back.summon.starsOf(RelicSlot.wing), 4);
  });
```

함수 이름(`encodeSave`/`decodeSave`)은 그 파일이 실제로 쓰는 것을 확인하고 맞춰라. import도 필요한 만큼만 더한다.

- [ ] **Step 8: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, Flutter 263 통과(254 + `summon_test.dart` 8 + `save_codec_test.dart` 1).

백엔드는 안 건드리므로 돌릴 필요가 없다.

- [ ] **Step 9: 커밋**

```bash
git add flutter/lib/domain flutter/lib/data flutter/test/domain
git commit -m "feat(domain): 소환석과 유물 네 칸 — 용화 단계는 성급 합의 평균

부위마다 성급 하나만 갖는다. 중복은 승급에 쓰이므로 여러 개를 들고
있을 일이 없다. 용화 단계를 최솟값이 아니라 합으로 재는 이유는
무료 소환이라 한 칸이 안 나오면 그 벽이 몇 주가 되기 때문이다.

저장은 'summon' 한 칸. 폴백이 있어 옛 저장도 열린다.

스펙 3절.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 2: 소환을 굴린다 — 확률·중복 승급·천장

**Files:**
- Modify: `flutter/lib/domain/summon.dart` (`SummonResult`, `rollRelic`, `applyRelic`, `summon`)
- Test: `flutter/test/domain/summon_test.dart` (추가)

**Interfaces:**
- Consumes: Task 1의 `SummonState`·`RelicSlot`·`BalanceConfig.summonCost`·`summonPity`
- Produces:
  - `class SummonResult { RelicSlot slot; int stars; bool byPity; bool upgraded; }`
  - `SummonResult rollRelic(Random rng, {required bool pityReached})`
  - `(SummonState, List<SummonResult>) summonRelics(SummonState s, Random rng, BalanceConfig c, {required int count})`
- Task 5의 화면이 `List<SummonResult>` 를 결과 목록에 그린다.

**중복 승급 규칙** (스펙 3.2 "중복이 나오면 그 유물의 성급이 오른다"를 구체화한 것):

| 지금 성급 | 나온 성급 | 되는 값 |
|---|---|---|
| 0 (없음) | r | **r** |
| c > 0 | r | **max(c + 1, r), 최대 5** |

높은 성급이 나오면 그 값으로 뛰고, 낮게 나와도 +1은 오른다. **헛도는 소환이 없다.** 무료 소환이라 뽑는 횟수가 적어서 한 번이라도 버려지면 안 된다.

**천장**: 소환할 때마다 `pityCount` 가 1 오른다. `pityCount >= c.summonPity` 이면 그 한 번은 ★5 확정(`byPity: true`). ★5가 나오면(굴려서든 확정이든) `pityCount` 는 0으로 돌아간다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`summon_test.dart` 끝에 더한다. `import 'dart:math';` 가 필요하다.

```dart
  group('굴리기', () {
    test('성급 분포가 표와 맞는다', () {
      // 고정 씨앗으로 1만 번 굴려 표(60/25/10/4/1)에 가까운지 본다.
      final rng = Random(7);
      final counts = <int, int>{};
      for (var i = 0; i < 10000; i++) {
        final r = rollRelic(rng, pityReached: false);
        counts[r.stars] = (counts[r.stars] ?? 0) + 1;
      }
      expect(counts[1]! / 10000, closeTo(0.60, 0.03));
      expect(counts[2]! / 10000, closeTo(0.25, 0.03));
      expect(counts[3]! / 10000, closeTo(0.10, 0.02));
      expect(counts[4]! / 10000, closeTo(0.04, 0.015));
      expect(counts[5]! / 10000, closeTo(0.01, 0.01));
    });

    test('부위는 균등하다', () {
      final rng = Random(11);
      final counts = <RelicSlot, int>{};
      for (var i = 0; i < 8000; i++) {
        final r = rollRelic(rng, pityReached: false);
        counts[r.slot] = (counts[r.slot] ?? 0) + 1;
      }
      for (final slot in RelicSlot.values) {
        expect(counts[slot]! / 8000, closeTo(0.25, 0.03), reason: '${slot.label}');
      }
    });

    test('천장에 닿으면 ★5가 확정으로 나온다', () {
      final rng = Random(3);
      for (var i = 0; i < 50; i++) {
        final r = rollRelic(rng, pityReached: true);
        expect(r.stars, 5);
        expect(r.byPity, isTrue);
      }
    });
  });

  group('승급', () {
    test('빈 칸이면 나온 성급 그대로', () {
      final (after, results) = summonRelics(
        const SummonState(stones: 300), Random(1), config, count: 1);
      final slot = results.single.slot;
      expect(after.starsOf(slot), results.single.stars);
    });

    test('이미 있으면 최소 +1 오른다 — 헛도는 소환이 없다', () {
      // 뿔 ★3을 갖고 뿔 ★1이 나와도 ★4가 된다.
      expect(mergeStars(current: 3, rolled: 1), 4);
      expect(mergeStars(current: 3, rolled: 5), 5);
      expect(mergeStars(current: 0, rolled: 2), 2);
      expect(mergeStars(current: 5, rolled: 1), 5, reason: '상한을 넘지 않는다');
    });
  });

  group('소환 실행', () {
    test('소환석이 모자라면 아무 일도 없다', () {
      const poor = SummonState(stones: 10);
      final (after, results) = summonRelics(poor, Random(1), config, count: 1);
      expect(results, isEmpty);
      expect(after.stones, 10, reason: '값을 안 깎는다');
    });

    test('1회는 summonCost를, 10회는 summonTenCost를 깎는다', () {
      final (one, _) = summonRelics(const SummonState(stones: 1000), Random(1), config, count: 1);
      expect(one.stones, 1000 - config.summonCost);
      final (ten, tenResults) = summonRelics(const SummonState(stones: 1000), Random(1), config, count: 10);
      expect(ten.stones, 1000 - config.summonTenCost);
      expect(tenResults, hasLength(10));
    });

    test('천장 카운터가 오르고 ★5에서 0으로 돌아간다', () {
      // 천장 직전까지 채운 상태에서 한 번 뽑으면 ★5가 나오고 카운터가 0이 된다.
      final start = SummonState(stones: 1000, pityCount: config.summonPity - 1);
      final (after, results) = summonRelics(start, Random(5), config, count: 1);
      expect(results.single.stars, 5);
      expect(after.pityCount, 0);
    });
  });
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/domain/summon_test.dart 2>&1 | tail -15
```

기대: `rollRelic`·`mergeStars`·`summonRelics` 가 없어 컴파일 실패.

- [ ] **Step 3: 굴리기와 승급을 쓴다**

`summon.dart` 끝에 더한다.

```dart
/// 소환 한 건의 결과.
class SummonResult {
  const SummonResult({
    required this.slot,
    required this.stars,
    required this.byPity,
    this.upgraded = false,
  });

  final RelicSlot slot;

  /// 굴려 나온 성급(1~5). 실제로 오른 값은 upgraded와 함께 봐야 한다.
  final int stars;

  /// 천장으로 확정된 것인지.
  final bool byPity;

  /// 이미 갖고 있던 부위라 승급으로 들어갔는지.
  final bool upgraded;
}

/// 성급 확률표. 스펙 8.1과 같아야 한다 — 화면의 `확률 보기`도 이 표를 읽는다.
const relicStarChances = <int, double>{1: 0.60, 2: 0.25, 3: 0.10, 4: 0.04, 5: 0.01};

/// 유물 하나를 뽑는다. 부위는 균등, 성급은 표. 천장에 닿았으면 ★5 확정.
SummonResult rollRelic(Random rng, {required bool pityReached}) {
  final slot = RelicSlot.values[rng.nextInt(RelicSlot.values.length)];
  if (pityReached) {
    return SummonResult(slot: slot, stars: SummonState.maxStars, byPity: true);
  }
  var r = rng.nextDouble();
  for (final entry in relicStarChances.entries) {
    if (r < entry.value) return SummonResult(slot: slot, stars: entry.key, byPity: false);
    r -= entry.value;
  }
  return SummonResult(slot: slot, stars: 1, byPity: false);
}

/// 이미 가진 성급과 나온 성급을 합친다.
///
/// 낮게 나와도 +1은 오른다. 무료 소환이라 뽑는 횟수가 적어서
/// 한 번이라도 버려지면 안 된다(스펙 3.2).
int mergeStars({required int current, required int rolled}) =>
    current == 0 ? rolled : max(current + 1, rolled).clamp(1, SummonState.maxStars);

/// 소환을 count번 굴려 새 상태와 결과 목록을 돌려준다.
///
/// 소환석이 모자라면 아무 일도 안 하고 빈 목록을 돌려준다 — 값을 깎지 않는다.
(SummonState, List<SummonResult>) summonRelics(
  SummonState s,
  Random rng,
  BalanceConfig c, {
  required int count,
}) {
  final cost = count == 1 ? c.summonCost : c.summonTenCost;
  if (s.stones < cost) return (s, const []);

  final relics = {...s.relics};
  final results = <SummonResult>[];
  var pity = s.pityCount;

  for (var i = 0; i < count; i++) {
    pity += 1;
    final rolled = rollRelic(rng, pityReached: pity >= c.summonPity);
    final current = relics[rolled.slot] ?? 0;
    relics[rolled.slot] = mergeStars(current: current, rolled: rolled.stars);
    results.add(SummonResult(
      slot: rolled.slot,
      stars: rolled.stars,
      byPity: rolled.byPity,
      upgraded: current > 0,
    ));
    if (rolled.stars >= SummonState.maxStars) pity = 0;
  }

  return (s.copyWith(stones: s.stones - cost, relics: relics, pityCount: pity), results);
}
```

`count` 는 1 또는 10만 온다. 다른 값은 `summonTenCost` 를 물게 되므로 호출부(Task 5)가 둘만 쓴다.

- [ ] **Step 4: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, 271 통과(263 + 새 테스트 8).

분포 테스트가 씨앗에 따라 흔들리면 **오차 범위를 넓히지 말고** 표본을 키워라(10000 → 40000). 그래도 안 맞으면 `rollRelic` 의 누적 확률 계산이 틀린 것이다.

- [ ] **Step 5: 커밋**

```bash
git add flutter/lib/domain/summon.dart flutter/test/domain/summon_test.dart
git commit -m "feat(domain): 소환을 굴린다 — 확률표·중복 승급·천장

낮은 성급이 나와도 이미 가진 부위면 +1 오른다. 무료 소환이라
뽑는 횟수가 적어 한 번이라도 헛돌면 안 된다.

천장에 닿으면 ★5 확정이고 ★5가 나오면 카운터가 0으로 돌아간다.
소환석이 모자라면 값을 안 깎고 빈 목록을 돌려준다.

스펙 3.2·8.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 3: 유물이 실제로 세지게 한다

**Files:**
- Modify: `flutter/lib/domain/upgrade.dart` (`Stats.withRelics`)
- Modify: `flutter/lib/domain/game_state.dart` (`statsWith` 사슬, `maxHeroHp`)
- Test: `flutter/test/domain/summon_test.dart` (추가)

**Interfaces:**
- Consumes: Task 1의 `SummonState`·`relicBonus`·`dragonMultiplier`
- Produces: `Stats withRelics(SummonState summon, BalanceConfig c)` — `Stats` 사슬의 마지막 칸

**`GameState` 는 `const GameState()` 로 못 만든다** — `stage`·`highestStage`·`gold` 등이 `required` 다.
이 저장소의 테스트는 전부 `GameState.initial(config)` 로 시작하고 `copyWith` 로 바꾼다. 그 방식을 따라라.

**어디에 무엇이 걸리나:**

| 유물 | 어디에 |
|---|---|
| 뿔 | `Stats.attack` |
| 꼬리 | `Stats.attacksPerSecond` |
| 날개 | `Stats.critChance` (**더하기**, 곱하기가 아니다 — 0~1 확률이다) |
| 비늘 | `GameState.maxHeroHp` (**`Stats` 에 체력이 없다**) |

**용화 배수는 `attack`·`attacksPerSecond`·`goldMultiplier` 세 곳에만 곱한다.** 스펙 3.3이 "전 스탯 곱연산"이라 했지만 `critChance` 는 0~1 확률이라 곱하면 상한을 넘긴다. 이 예외를 Task 6이 스펙에 적는다.

- [ ] **Step 1: 지금 사슬을 확인한다**

```bash
cd flutter
grep -n "statsWith" lib/domain/game_state.dart
grep -n "Stats scaledBy\|Stats withPet\|min(1.0, critChance" lib/domain/upgrade.dart
grep -n "maxHeroHp" -A3 lib/domain/game_state.dart
```

기대: `Stats.fromLevels(...).scaledBy(equipment.powerWith(config)).withPet(pets)` 사슬이 보이고, `withPet` 이 `critChance` 를 `min(1.0, ...)` 으로 묶는다. **`withRelics` 도 같은 방식으로 묶어라.**

- [ ] **Step 2: 실패하는 테스트를 쓴다**

```dart
  group('스탯 반영', () {
    test('유물이 없으면 스탯이 그대로다', () {
      const stats = Stats(attack: 100, attacksPerSecond: 2, critChance: 0.1, goldMultiplier: 1);
      final after = stats.withRelics(SummonState.empty, config);
      expect(after.attack, 100);
      expect(after.attacksPerSecond, 2);
      expect(after.critChance, 0.1);
      expect(after.goldMultiplier, 1);
    });

    test('뿔은 공격력, 꼬리는 공속, 날개는 치명타에 걸린다', () {
      const stats = Stats(attack: 100, attacksPerSecond: 2, critChance: 0.1, goldMultiplier: 1);
      // 뿔 ★5(+30%) 하나뿐이면 성급 합 5 → 용화 1단계(×1.06).
      const one = SummonState(relics: {RelicSlot.horn: 5});
      final a = stats.withRelics(one, config);
      expect(a.attack, closeTo(100 * 1.30 * 1.06, 1e-6));
      expect(a.attacksPerSecond, closeTo(2 * 1.06, 1e-6), reason: '꼬리가 없어도 용화 배수는 걸린다');

      const wing = SummonState(relics: {RelicSlot.wing: 3});
      expect(stats.withRelics(wing, config).critChance, closeTo(0.1 + 0.15, 1e-6),
          reason: '치명타는 더하기다 — 곱하면 1.0을 넘긴다');
    });

    test('치명타는 1.0을 넘지 않는다', () {
      const stats = Stats(attack: 1, attacksPerSecond: 1, critChance: 0.95, goldMultiplier: 1);
      const wing = SummonState(relics: {RelicSlot.wing: 5});
      expect(stats.withRelics(wing, config).critChance, 1.0);
    });

    test('비늘은 최대 체력에 걸린다', () {
      final bare = GameState.initial(config);
      final scaled = bare.copyWith(summon: const SummonState(relics: {RelicSlot.scale: 4}));
      expect(scaled.maxHeroHp(config), closeTo(bare.maxHeroHp(config) * 1.22, 1e-6));
    });

    test('statsWith가 유물을 거친다 — 사슬에 붙어 있어야 한다', () {
      final bare = GameState.initial(config);
      final horned = bare.copyWith(summon: const SummonState(relics: {RelicSlot.horn: 5}));
      expect(horned.statsWith(config).attack, greaterThan(bare.statsWith(config).attack));
    });
  });
```

`Stats` 와 `GameState` 를 import에 더해야 한다.

- [ ] **Step 3: 실패를 확인한다**

```bash
cd flutter && flutter test test/domain/summon_test.dart 2>&1 | tail -15
```

기대: `withRelics` 가 없어 컴파일 실패.

- [ ] **Step 4: `Stats.withRelics` 를 쓴다**

`flutter/lib/domain/upgrade.dart` — `withPet` 바로 아래에 더한다. import에 `import 'summon.dart';` 가 필요하다.

```dart
  /// 유물 네 칸과 용화 단계를 얹는다.
  ///
  /// 용화 배수는 공격력·공속·골드에만 곱한다. 치명타는 0~1 확률이라
  /// 곱하면 상한을 넘기므로 날개 보정을 **더하고** 1.0으로 묶는다.
  Stats withRelics(SummonState summon, BalanceConfig c) {
    if (summon.totalStars == 0) return this;
    final m = dragonMultiplier(summon.dragonStage, c);
    return Stats(
      attack: attack * (1 + relicBonus(summon.starsOf(RelicSlot.horn))) * m,
      attacksPerSecond: attacksPerSecond * (1 + relicBonus(summon.starsOf(RelicSlot.tail))) * m,
      critChance: min(1.0, critChance + relicBonus(summon.starsOf(RelicSlot.wing))),
      goldMultiplier: goldMultiplier * m,
    );
  }
```

- [ ] **Step 5: 사슬과 체력에 잇는다**

`flutter/lib/domain/game_state.dart`:

```dart
  Stats statsWith(BalanceConfig config) => Stats.fromLevels(levels, config, passives)
      .scaledBy(equipment.powerWith(config))
      .withPet(pets)
      .withRelics(summon, config);
```

`maxHeroHp` 에 비늘을 곱한다. 주석 한 줄을 남겨라 — 왜 `Stats` 가 아니라 여기인지 다음 사람이 묻는다:

```dart
  /// 비늘은 여기 걸린다. `Stats` 에는 체력 칸이 없다.
  double maxHeroHp(BalanceConfig c) =>
      (c.heroHpBase + c.heroHpPerLevel * totalUpgradeLevels) *
      pow(c.heroHpStageGrowth, highestStage - 1) *
      (1 + relicBonus(summon.starsOf(RelicSlot.scale)));
```

- [ ] **Step 6: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, 276 통과(271 + 새 테스트 5).

**기존 전투·오프라인 보상 테스트가 깨지면 그것부터 보라.** 유물이 비어 있으면 `withRelics` 가 `this` 를 그대로 돌려주므로 기존 테스트는 안 깨져야 한다. 깨졌다면 빈 상태 조기 반환이 빠진 것이다.

- [ ] **Step 7: 커밋**

```bash
git add flutter/lib/domain flutter/test/domain/summon_test.dart
git commit -m "feat(domain): 유물이 실제로 세지게 한다 — 사슬에 한 칸을 잇는다

Stats 사슬 끝에 withRelics를 붙였다. 뿔은 공격력, 꼬리는 공속,
날개는 치명타. 비늘은 Stats에 체력 칸이 없어 maxHeroHp에 건다.

용화 배수는 공격력·공속·골드에만 곱한다. 치명타는 0~1 확률이라
곱하면 상한을 넘긴다.

스펙 3.3·3.4.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 4: 소환석을 벌게 한다

**Files:**
- Modify: `flutter/lib/domain/quest.dart` (`RewardKind.summonStone`, `grantQuestReward`)
- Modify: `flutter/lib/domain/battle_engine.dart` (지역 첫 진입 지급)
- Test: `flutter/test/domain/summon_test.dart` · `flutter/test/domain/quest_test.dart`

**Interfaces:**
- Consumes: Task 1의 `SummonState.regionsRewarded`·`BalanceConfig.summonStonePerRegion`·`summonStonePerQuest`
- Produces: `GameState grantRegionStones(GameState s, MonsterCatalog catalog, BalanceConfig c)`

**공짜로 얻는 것 하나**: 퀘스트 21~60번의 보상은 `RewardKind.values[(number - 1) % RewardKind.values.length]` 로 정해진다(`quest.dart` 의 `_questAt`). **`RewardKind` 에 값을 하나 더하면 뒤 40개 퀘스트에 자동으로 섞인다.** 새 장치가 필요 없다.

부작용도 있다. 나머지 값(5 → 6)이 바뀌므로 **21~60번의 기존 보상 배정이 통째로 달라진다.** 밸런스 변경이지 버그가 아니다. 그 번호들의 보상을 못 박은 테스트가 있으면 새 배정으로 고쳐라 — 다만 **왜 바뀌었는지 주석을 남겨라.**

- [ ] **Step 1: 지금 배정을 확인한다**

```bash
cd flutter
grep -n "RewardKind.values\[" lib/domain/quest.dart
grep -rn "questTable\[" test/domain/quest_test.dart | head
flutter test test/domain/quest_test.dart 2>&1 | tail -3
```

기대: `_questAt` 이 나머지 연산으로 보상을 고르고, 퀘스트 테스트가 지금은 통과한다. **어느 테스트가 번호별 보상을 못 박고 있는지 리포트에 적어라** — Step 5에서 그것만 고친다.

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`summon_test.dart` 에 지역 지급을, `quest_test.dart` 에 퀘스트 보상을 더한다.

```dart
  group('지역 첫 진입', () {
    BattleEngine engineWith(MonsterCatalog catalog) => BattleEngine(config, catalog: catalog);

    test('지역을 처음 밟을 때마다 소환석을 준다', () {
      final after = engineWith(_twoRegionCatalog()).grantRegionStones(GameState.initial(config));
      expect(after.summon.stones, config.summonStonePerRegion, reason: '첫 지역 하나');
      expect(after.summon.regionsRewarded, 1);
    });

    test('같은 지역에서 또 부르면 안 준다 — 여러 번 불려도 안전해야 한다', () {
      final engine = engineWith(_twoRegionCatalog());
      final once = engine.grantRegionStones(GameState.initial(config));
      final twice = engine.grantRegionStones(once);
      expect(twice.summon.stones, once.summon.stones);
    });

    test('여러 지역을 건너뛰어도 밀린 만큼 다 준다', () {
      final after = engineWith(_twoRegionCatalog()).grantRegionStones(GameState.initial(config).copyWith(highestStage: 500));
      expect(after.summon.stones, config.summonStonePerRegion * 2);
      expect(after.summon.regionsRewarded, 2);
    });

    test('카탈로그가 비면 아무 일도 없다', () {
      final after = engineWith(MonsterCatalog.empty).grantRegionStones(GameState.initial(config).copyWith(highestStage: 500));
      expect(after.summon.stones, 0);
    });
  });
```

`_twoRegionCatalog()` 는 이 테스트 파일 안에 손으로 만든다. **`MonsterCatalog` 와 `Region` 의 실제 생성자를 읽고 맞춰라** — `Region` 은 `id`·`name`·`stageFrom`·`stageTo`·`completionKind`·`completionValue` 를 받는다. 지역 둘(1~99, 100~)이면 충분하다.

`quest_test.dart` 에:

```dart
  test('소환석도 퀘스트 보상으로 나온다', () {
    final kinds = {for (final q in questTable) q.reward};
    expect(kinds, contains(RewardKind.summonStone));
  });

  test('소환석 퀘스트를 받으면 소환석이 는다', () {
    final quest = questTable.firstWhere((q) => q.reward == RewardKind.summonStone);
    final before = GameState.initial(const BalanceConfig());
    final after = grantQuestReward(before, quest, const BalanceConfig());
    expect(after.summon.stones, quest.rewardAmount);
  });
```

- [ ] **Step 3: 실패를 확인한다**

```bash
cd flutter && flutter test test/domain/summon_test.dart test/domain/quest_test.dart 2>&1 | tail -15
```

기대: `RewardKind.summonStone` 과 `grantRegionStones` 가 없어 컴파일 실패.

- [ ] **Step 4: 보상 종류를 더한다**

`flutter/lib/domain/quest.dart`:

```dart
enum RewardKind {
  gold('골드'),
  stone('강화석'),
  ticket('입장권'),
  eggShard('용의 알 조각'),
  skillPage('스킬서 조각'),
  summonStone('소환석');
```

`grantQuestReward` 의 `switch` 에 한 갈래를 더한다. **이 `switch` 는 빠짐없이 다뤄야 컴파일된다** — 그래서 빠뜨릴 수 없다.

```dart
    RewardKind.summonStone =>
      s.copyWith(summon: s.summon.copyWith(stones: s.summon.stones + amount)),
```

앞 20개 손으로 적은 퀘스트(`_openingQuests`)는 **건드리지 마라.** 소환 화면은 초반에 없다.

**소환석 퀘스트의 양**: `_questAt` 이 `rewardAmount` 를 어떻게 정하는지 읽고, 소환석일 때 `c.summonStonePerQuest` 를 쓰게 하라. 다른 재화의 양 규칙을 그대로 두고 소환석만 분기하는 것이 가장 작은 변경이다. `_questAt` 이 `BalanceConfig` 를 못 받는 구조면 상수 60을 그 파일에 두고 `balance_config` 의 값과 같다는 주석을 남겨라 — 그리고 그 사실을 리포트에 적어라.

- [ ] **Step 5: 지역 첫 진입 지급을 쓴다**

`flutter/lib/domain/battle_engine.dart` 에 더한다. `catalog` 는 이미 필드로 있다(`battle_engine.dart:34`).

```dart
  /// 지역을 처음 밟을 때마다 소환석을 준다.
  ///
  /// `regionsRewarded` 를 세는 방식이라 여러 번 불려도 안전하다.
  /// 저장을 지웠다 복구해도 이미 준 것을 또 주지 않는다.
  GameState grantRegionStones(GameState s) {
    if (catalog.regions.isEmpty) return s;
    final reached = catalog.regions.where((r) => s.highestStage >= r.stageFrom).length;
    final owed = reached - s.summon.regionsRewarded;
    if (owed <= 0) return s;
    return s.copyWith(
      summon: s.summon.copyWith(
        stones: s.summon.stones + config.summonStonePerRegion * owed,
        regionsRewarded: reached,
      ),
    );
  }
```

`highestStage` 가 오르는 자리에서 부른다:

```bash
grep -n "highestStage: max" lib/domain/battle_engine.dart
```

그 자리에서 상태를 만든 뒤 `grantRegionStones(...)` 를 통과시킨다. **층이 오르는 모든 경로**(전투 진행, 층 이동)에서 걸려야 하니 `grep -rn "highestStage" lib/domain lib/app` 로 전부 찾아 확인하고, 어디에 걸었는지 리포트에 적어라.

- [ ] **Step 6: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -5
```

기대: analyze 0건, 282 통과(276 + 새 테스트 6).

**퀘스트 21~60번의 보상 배정이 바뀌어 기존 테스트가 깨질 수 있다.** 깨지면 새 배정으로 고치고, 그 테스트에 주석 한 줄을 남겨라: `// RewardKind에 소환석이 들어와 나머지가 5→6이 됐다. 배정이 통째로 바뀐다.`

- [ ] **Step 7: 커밋**

```bash
git add flutter/lib/domain flutter/test/domain
git commit -m "feat(domain): 소환석을 벌게 한다 — 지역 첫 진입과 퀘스트 보상

퀘스트 21~60번이 RewardKind를 돌아가며 쓰므로 값을 하나 더하니
자동으로 섞였다. 새 장치가 없다. 대신 나머지가 5에서 6이 되어
그 번호들의 보상 배정이 통째로 바뀐다 — 밸런스 변경이다.

지역 첫 진입은 regionsRewarded를 세는 방식이라 여러 번 불려도
같은 지역을 두 번 주지 않는다.

스펙 5.2.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 5: 소환 화면

**Files:**
- Create: `flutter/lib/ui/summon_panel.dart`
- Modify: `flutter/lib/app/game_controller.dart` (`summonRelic`·`summonRelicTen`)
- Modify: `flutter/lib/ui/game_screen.dart` · `flutter/lib/ui/hud/menu_grid.dart` (`소환` 잠금 해제)
- Test: `flutter/test/ui/game_screen_test.dart`

**Interfaces:**
- Consumes: Task 2의 `summonRelics`·`SummonResult`·`relicStarChances`, Task 1의 `SummonState`, 팝업 골격의 `GamePopup`·`PopupTwoPane`·`PopupPane`·`showGamePopup`
- Produces: `class SummonPanel extends ConsumerStatefulWidget`, 컨트롤러의 `List<SummonResult> summonRelic({required int count})`

**화면 모양** (스펙 6절):

```
┌─[✦ 소환] (?)                    (✕)─┐
│  [ 유물 ] [ 정령 🔒 ]   확률 보기 ▸  │
│   지금 낀 것        │   나온 것       │
│   뿔  ★3            │   [뿔 ★2]      │
│   꼬리 ★2           │   [비늘 ★4]    │
│   날개 ★3           │                 │
│   비늘 ★2           │  ★5까지 37회   │
│   용화 2단계        │   소환석 240    │
│                     │ [1회] [10회]   │
└──────────────────────────────────────┘
```

- **왼쪽 단에는 일괄 버튼이 없다.** 중복이 자동 승급이라 고를 것이 없다(스펙 6절). `PopupPane.action` 을 안 넘기면 된다.
- 오른쪽 단 `action` 에 `1회`·`10회` 두 단추를 `Row` 로 넣는다.
- `정령` 탭은 **잠금**. 누르면 본문에 '정령 — 준비 중'만 보인다. 탭 자체는 눌린다.
- **붉은 경고(`warning:`)는 안 쓴다.** 되돌릴 수 없는 동작이 없다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`flutter/test/ui/game_screen_test.dart` 끝에 더한다.

```dart
  testWidgets('소환 단추가 소환 화면을 연다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('소환').first);
    await tester.pumpAndSettle();

    expect(find.text('유물'), findsWidgets);
    expect(find.text('정령'), findsWidgets);
    expect(find.textContaining('용화'), findsWidgets, reason: '왼쪽 단에 용화 단계');
    for (final label in ['뿔', '꼬리', '날개', '비늘']) {
      expect(find.text(label), findsWidgets, reason: '$label 칸');
    }
  });

  testWidgets('확률 보기가 표를 띄운다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('소환').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('확률 보기').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('60'), findsWidgets, reason: '★1 확률 60%');
    expect(find.textContaining('1%'), findsWidgets, reason: '★5 확률 1%');
  });

  testWidgets('연 직후 상태가 정해진 대로다 — 천장 90회, 용화 0단계, 단추 둘', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('소환').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('용화 0'), findsWidgets);
    expect(find.textContaining('90'), findsWidgets, reason: '천장 카운터는 pityCount 0에서 90회다');
    expect(find.text('1회'), findsWidgets);
    expect(find.text('10회'), findsWidgets);
  });

**이 테스트가 뽑기를 누르지 않는 이유**: 시작 소환석이 몇 개인지는 지역 첫 진입 지급(Task 4)이 위젯 테스트의 짧은 틱 동안 걸리는지에 달려 있어 정해지지 않는다. 굴리기는 도메인 테스트(Task 2)가 이미 덮으므로 화면 테스트는 **열림과 배선만** 확인한다.
```

**기존 테스트 하나를 반드시 고쳐야 한다.** `'잠금 단추는 화면을 열지 않고 준비 중만 알린다'` 테스트가 `find.text('소환').first` 를 탭한다(`game_screen_test.dart:175`). 소환이 열리므로 그 테스트는 **아직 잠긴 다른 단추**로 바꾼다 — `상점` 이 적당하다. 라벨만 바꾸고 나머지 단언은 그대로 둔다.

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/ui/game_screen_test.dart 2>&1 | tail -20
```

기대: `SummonPanel` 이 없어 실패하고, 잠금 테스트가 소환 때문에 실패한다. **둘 다 실패하는 것이 정상이다.**

- [ ] **Step 3: 컨트롤러에 명령을 낸다**

`flutter/lib/app/game_controller.dart` — 기존 명령(`craft()`·`startHatch()`)이 어떻게 상태를 바꾸고 `_rng` 를 쓰는지 먼저 보고 그 방식을 그대로 따라라.

```dart
  /// 유물을 count번 소환한다. 소환석이 모자라면 빈 목록.
  List<SummonResult> summonRelic({required int count}) {
    final (next, results) = summonRelics(state.summon, _rng, _config, count: count);
    if (results.isEmpty) return const [];
    state = state.copyWith(summon: next);
    return results;
  }
```

`_config` 와 `_rng` 의 실제 이름은 이 파일에서 확인하고 맞춰라. 상태를 어떻게 쓰는지(`state = ...` 인지 다른 방식인지)도 주변 명령을 보고 따라라.

- [ ] **Step 4: 화면을 만든다**

`flutter/lib/ui/summon_panel.dart` 를 만든다. `contents_panel.dart` 의 탭 구조와 `equipment_panel.dart` 의 `PopupTwoPane` 사용법을 본으로 삼아라 — **새 문법을 발명하지 마라.**

담을 것:
- 탭 둘(`유물`·`정령`). `정령` 은 본문이 `Center(child: PixelText('정령 — 준비 중', size: 12, color: PixelPalette.textDim))`.
- 유물 탭은 `PopupTwoPane`:
  - 왼쪽 `PopupPane`: 네 칸(`RelicSlot.values` 를 돌며 `label` 과 `★` 성급), 그 아래 `용화 N단계`, 다음 단계까지 남은 성급. `action` 을 안 넘긴다.
  - 오른쪽 `PopupPane`: 방금 나온 결과 목록(`List<SummonResult>` 를 `setState` 로 들고 있는다), 천장 카운터(`★5까지 N회` = `config.summonPity - state.summon.pityCount`), 소환석 잔량, `action` 에 `1회`·`10회`.
- 오른쪽 단 위에 `확률 보기` — 누르면 `showGamePopup` 으로 표를 띄운다. 표는 **`relicStarChances` 를 읽어 그린다.** 숫자를 손으로 다시 적으면 코드와 갈라진다.
- 결과가 나오면 기존 획득 연출을 쓴다: `showRewardPopup(context, title: '소환', icon: PixelIcon.spark, lines: [...])`. **새 연출은 계획 2의 일이다.**

`GamePopup` 은 `icon: PixelIcon.spark`, `help: '유물을 뽑아 주인공을 용으로 키운다. 중복은 승급에 쓰인다.'` 로 연다.

- [ ] **Step 5: 진입점 둘을 연다**

`flutter/lib/ui/game_screen.dart` 우상단:

```dart
                  HudButton(
                    label: '소환',
                    icon: PixelIcon.spark,
                    onTap: () => showGamePopup(context, title: '소환', icon: PixelIcon.spark,
                        help: '유물을 뽑아 주인공을 용으로 키운다. 중복은 승급에 쓰인다.',
                        child: const SummonPanel()),
                  ),
```

`locked: true` 를 **지운다.** `flutter/lib/ui/hud/menu_grid.dart` 의 `소환` 칸도 같은 방식으로 `_open(...)` 을 부르게 바꾼다(그 파일의 `_open` 서명을 보고 맞춰라).

**나머지 잠긴 자리(상점·전용무기·광고·캐릭터·강화·영지·동료·랭킹·도움말·설정)는 건드리지 마라.**

- [ ] **Step 6: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -5
```

기대: analyze 0건, 285 통과(282 + 새 테스트 3, 기존 잠금 테스트는 탭 대상 라벨만 바뀌어 개수 그대로).

- [ ] **Step 7: 캡처로 눈으로 본다**

```bash
cd flutter && flutter test test/ui/art_gallery_test.dart 2>&1 | tail -3 && ls -la build/*.png
```

캡처에 소환 화면이 안 나오면(기본 화면만 찍힌다면) 그 사실을 리포트에 적어라. **캡처를 위해 테스트를 바꾸지 마라.**

- [ ] **Step 8: 커밋**

```bash
git add flutter/lib flutter/test/ui/game_screen_test.dart
git commit -m "feat(flutter): 소환 화면 — 유물 네 칸과 확률표

우상단과 메뉴 그리드의 소환 자물쇠를 풀었다. 팝업 골격을 그대로
써서 새로 만든 것은 화면 내용뿐이다. 왼쪽 단에 일괄 단추가 없는
것은 중복이 자동 승급이라 고를 것이 없기 때문이다.

확률표는 relicStarChances를 읽어 그린다. 손으로 적으면 갈라진다.
연출은 기존 획득 연출을 쓴다 — 소환 전용 연출은 계획 2다.

스펙 6절.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 6: 문서

**Files:**
- Modify: `GAME_DESIGN.md` (11장)
- Modify: `docs/superpowers/specs/2026-09-05-summon-design.md` (구현 뒤 실제와 다른 곳)
- Modify: `docs/BACKLOG.md`

- [ ] **Step 1: 11장에 소환을 적는다**

`GAME_DESIGN.md` 11장 `### 하지 않는 것` 목록의 첫 줄이 이렇다:

```
- 뽑기·확률형 유료 아이템 (차별화와 충돌, 확률 공시 부담)
```

**이 줄을 지우지 마라.** 소환은 유료가 아니다. 목록 **아래**에 문단 하나를 더한다:

```markdown
**소환은 예외가 아니다 (2026-09-05).** 유물·정령 소환은 **소환석**으로 돌고 소환석은 돈으로 못 산다 —
던전·퀘스트·과제·광고로만 얻는다. 유상 구매가 없으므로 게임산업법 확률 공시 의무 대상이 아니지만
**확률표는 자발적으로 공개한다.** 설계는 `docs/superpowers/specs/2026-09-05-summon-design.md`.

같은 목록의 **도감 정수 금지도 그대로다.** 유물 성급은 소환 중복으로만 오르고 재화로는 못 산다.

**규칙: 소환석이 나오는 던전에는 다이아 소탕권을 팔지 않는다.** 지금은 소환석이 던전에서 안 나와
이 경로가 없지만, 나중에 붙이는 사람이 밟을 지뢰라 여기 표시해 둔다 —
`다이아 → 소탕권 → 던전 → 소환석` 이 되면 "간접적으로 유상 구매"라 확률 공시가 법적 의무가 된다.
```

`### 1층: 리워드 광고` 의 표에는 **아직 줄을 더하지 마라.** 광고 소환석은 이 계획에 없다(광고 SDK는 백로그 C3).

- [ ] **Step 2: 스펙에 실제와 다른 곳을 적는다**

`docs/superpowers/specs/2026-09-05-summon-design.md` 의 **3.3절 끝**(용화 단계 표와 배수 설명 뒤)에 한 문단을 더한다:

```markdown
**2026-09-05 구현 뒤**: 용화 배수는 **공격력·공속·골드에만** 곱한다. 치명타는 0~1 확률이라
곱하면 상한을 넘기므로 날개 보정을 더하고 `min(1.0, …)` 으로 묶는다(`upgrade.dart` 의 `Stats.withRelics`).
비늘은 `Stats` 에 체력 칸이 없어 `GameState.maxHeroHp` 에 건다.
```

**11절(구현 순서) 끝**에도 한 줄:

```markdown
**계획 1 완료 시점(2026-09-05)**: 도메인·수급·스탯·화면까지. 소환 전용 연출은 기존 획득 연출을
그대로 쓰고 있고, 주인공 스프라이트는 안 바뀐다(용화 단계는 글자로만 보인다). 둘 다 계획 2·아트 발주의 일이다.
```

- [ ] **Step 3: 백로그에 남긴다**

`docs/BACKLOG.md` 끝에 더한다(마지막 `###` 항목 뒤).

```markdown
### D6. 소환 반복 수급 · S
계획 1의 소환석은 **진도 보상뿐이다** — 지역 첫 진입 10회와 퀘스트 약 7회, 합쳐 약 1,900석(소환 63회).
다 쓰면 더 벌 길이 없어 천장(90회)에 못 닿는다. 오늘 과제(과제당 20)와 리워드 광고(회당 15, 일 3회)를
붙여야 반복 수급이 생긴다. 광고는 SDK(C3) 뒤다. 과제는 지금도 가능하지만 `DailyGoal` 3종의 보상을
바꾸면 기존 보상이 하나 사라지므로, 넷째 과제를 더할지 완료 덤을 줄지 먼저 정한다.

### D6-1. 소환 계수를 서버에서 조정하기 · S
소환 계수 6개(`summonCost`·`summonTenCost`·`summonPity`·`summonStonePerRegion`·`summonStonePerQuest`·`dragonStageMultiplier`)가
지금은 클라이언트 기본값으로만 산다. `balance_codec.dart` 가 폴백으로 읽으므로 서버가 안 보내도 돌아가지만,
**밸런스를 고치려면 앱을 새로 내야 한다.** 서버로 내보내려면 `balance.json` 말고도
`masterdata/app/dtos/balance_dto.py`·`masterdata/app/ports/output/balance_source_port.py`·`hub/app/dtos/balance_dto.py`·
`save/domain/balance/formulas.py`와 테스트 지원 넷을 같이 고쳐야 한다. 수급량을 실제로 조정할 때(스펙 12절) 한다.

### D7. 용화 단계 스프라이트 · M
용화 0~5단계가 지금은 글자로만 보인다. `ART_GUIDE.md` 2절의 용 단계 표(뿔·꼬리·날개막·비늘)를 주인공에게
입힌다. 스펙 12절의 기울기는 **부위를 겹치는 쪽** — 5장을 따로 그리면 주인공 그림을 바꿀 때 5장을 다 다시 그린다.
`battle_stage_game.dart` 가 `_heroSheetId = 'warrior_1'` 로 시트 하나를 읽으므로 겹치려면 로더가 여러 장을 얹을 수 있어야 한다.
```

- [ ] **Step 4: 확인하고 커밋**

```bash
cd flutter && flutter test 2>&1 | tail -2
cd .. && grep -n "소환은 예외가 아니다" GAME_DESIGN.md && grep -n "^### D6\|^### D6-1\|^### D7" docs/BACKLOG.md
```

기대: 테스트 285 통과(문서만 고쳤으니 그대로), 세 문서에 새 줄이 있다.

```bash
git add GAME_DESIGN.md docs/superpowers/specs/2026-09-05-summon-design.md docs/BACKLOG.md
git commit -m "docs: 소환을 기획 정본에 적는다 — 무료라 예외가 아니다

11장의 '뽑기·확률형 유료 아이템 안 함'은 그대로 산다. 소환석은
돈으로 못 사므로 그 줄에 안 걸린다. 확률 공시는 법적 의무가
아니지만 표는 공개한다.

소환석이 나오는 던전에 다이아 소탕권을 팔지 않는다는 규칙을
지금 표시해 둔다. 지금은 경로가 없지만 나중에 밟을 지뢰다.

백로그 D6(반복 수급)·D7(용화 스프라이트).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

## 이 계획이 하지 않는 것

- **정령을 만들지 않는다.** 탭 자리만 두고 잠근다(스펙 계획 3).
- **소환 전용 연출을 만들지 않는다.** 소환진·빛기둥·건너뛰기는 계획 2다. 지금은 기존 획득 연출을 쓴다.
- **주인공 스프라이트를 안 바꾼다.** 용화 단계는 글자로만 보인다(백로그 D7).
- **광고·오늘 과제 수급을 안 붙인다.** 광고 SDK가 없다(백로그 C3·D6).
- **던전을 안 건드린다.** 재화 1:1 원칙(스펙 5.3).
- **서버에서 소환을 굴리지 않는다.** 클라이언트가 굴린다(스펙 12절). 랭킹 경쟁이 붙는 시점에 옮긴다.
- **전용무기를 안 만든다.** 하단 바의 `무기` 칸은 잠긴 채로 둔다.

## 알려진 위험

| 위험 | 어디서 터지나 | 대응 |
|---|---|---|
| `RewardKind` 에 값을 더하면 퀘스트 21~60의 보상 배정이 통째로 바뀐다 | Task 4 Step 6 | 의도한 것이다. 깨진 테스트를 새 배정으로 고치고 주석을 남긴다 |
| `grantQuestReward` 의 `switch` 가 컴파일을 막는다 | Task 4 Step 4 | 좋은 일이다. 빠뜨릴 수 없다 |
| 옛 저장에 `summon` 키가 없다 | Task 1 Step 7 | `?? const {}` 폴백. 이것이 유일한 장치다 |
| `withRelics` 가 빈 상태에서도 값을 바꾸면 기존 전투 테스트가 다 깨진다 | Task 3 Step 6 | `totalStars == 0` 이면 `this` 를 그대로 돌려준다 |
| 기존 잠금 회귀 테스트가 `소환` 을 탭한다 | Task 5 Step 1 | `상점` 으로 바꾼다. 라벨만 바꾸고 단언은 둔다 |
| 확률 테스트가 씨앗에 따라 흔들린다 | Task 2 Step 4 | 오차 범위를 넓히지 말고 표본을 키운다 |
| `balance.json` 과 클라이언트 폴백이 갈라진다 | Task 1 Step 4 | 서버 값이 클라이언트를 덮으므로 조용히 달라진다. 같은 값을 넣었는지 리포트에 적는다 |
| `PopupPane` 은 높이가 확정된 곳에서만 쓴다 | Task 5 Step 4 | `GamePopup` 본문 안이라 안전하다. 다른 곳에 옮기지 마라 |

## 실행 기록 (2026-09-05)

브랜치 `feat/summon-relics`, 13커밋. 태스크 6개 전부 리뷰 통과 · 전체 브랜치 리뷰 "수정 후 병합" → 수정 2커밋 → 범위 재리뷰 승인. 테스트 254 → 287.

**전체 리뷰가 잡은 것 둘이 이 계획의 값이었다.**

1. **퀘스트 보상이 목표와 1:1로 굳었다.** `RewardKind` 가 5→6이 되며 보상 주기가 퀘스트 목표 주기(6)와 같아져, 21~60번에서 각 목표가 보상 하나에 영구히 용접됐다 — `층 도달` 일곱 개가 전부 입장권 1장. **소환과 무관한 기존 시스템의 회귀**였고, 계획이 "값을 하나 더하면 자동으로 섞인다"고 쓴 것의 정확한 반대였다. 보상 인덱스에 `number ~/ length` 항을 더해 어긋냈고, 용접을 잡는 테스트를 넣었다.
2. **유물이 장비를 이겼다.** 용화 배수를 공격력과 공속 둘 다에 곱했는데 DPS = 공격력 × 공속이라 **제곱으로 들어가** 만렙 ×3.64가 됐다. 스펙 3.4("유물이 장비보다 세면 대장간이 죽는다")를 어겼다. 공격력 하나에만 걸어 ×2.9로 내렸다.

**경제 진단이 반대였다.** 계획·스펙·백로그가 모두 "다 쓰면 부족해 천장에 못 닿는다"고 적었으나, 전체 리뷰가 몬테카를로로 재보니 **만렙까지 평균 26.6회**(`mergeStars` 가 중복마다 최소 +1을 주기 때문)라 공급 64회 중 **1,000석이 남는다.** 천장 90회는 죽은 장치다. D6을 "소환석의 소비처"로 다시 썼다.

**계획이 네 번 틀렸다.** `const GameState()`(컴파일 불가), 체력에 용화 배수 누락, 소환 63회(실제 64), 그리고 "값을 더하면 자동으로 섞인다". 전부 서브에이전트가 잡았다. 앞 계획(팝업 골격)의 다섯 번과 같은 패턴이다 — **계획서가 확인 없이 단언한 값.**

**판정(Ruling) 9건** — preflight 2, Task 1·3·6에서 각 1, 전체 리뷰에서 5.

**다음 계획에 넘긴 것**: D6(소환석 소비처 — 반복 수급보다 소비처가 먼저다), D6-1(밸런스 계수 서버 전달 + 서버가 유물을 모른다), D7(용화 스프라이트). 그리고 화면에 **승급이 한 번도 안 보인다**(`SummonResult.upgraded` 가 미사용) — 이 시스템의 핵심 루프인데 유저가 못 본다. 계획 2 화면 작업의 첫 항목이다.
