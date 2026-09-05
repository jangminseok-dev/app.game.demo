# 소환 3 — 정령 축 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 정령 4종을 소환해 하나를 데리고 다니고, 전투 중 게이지가 차면 스스로 나와 컷신과 함께 큰 피해를 준다.

**Architecture:** 도메인은 `lib/domain/spirit.dart` 하나다 — 4종·보유·편성·게이지·지속 효과가 한 덩어리다. 전투 루프는 `BattleEngine.tick` 에 게이지 한 줄과 발동 한 줄을 더하는 것이 전부이고, 피해는 기존 `_strike` 를 그대로 쓴다. 화면은 발동 횟수(`firedCount`)가 오르는 것을 보고 컷신을 띄운다 — 보스 경고·패배 안내가 이미 쓰는 `ref.listen` 방식이다.

**Tech Stack:** Flutter · Riverpod · 순수 Dart 도메인(`Random`·`dt` 를 밖에서 받는다) · `AnimationController` + `CustomPainter`(계획 2가 쓴 방식)

**Spec:** `docs/superpowers/specs/2026-09-05-summon-design.md` 4절(정령)·7.3절(등장 컷신)·8절(확률표와 천장)

## Global Constraints

- **정령 성급 상한은 ★5다.** 스펙 4.2가 계획 3에서 정하라고 남긴 것을 여기서 정한다 — 유물은 4칸이 다 쓰이지만 정령은 **1칸**이라 성급이 곧바로 힘이 된다. ★10까지 열면 한 마리에 몰아 넣는 것이 언제나 정답이 되어 4종을 만든 뜻이 사라진다.
- **게이지 90초를 60초 아래로 내리지 마라.** 스펙 4.3이 "정령이 매번 컷신을 띄워도 화면 지도 5절을 안 어긴다"는 근거로 이 값을 든다. 내리면 그 근거가 무너진다.
- **컷신은 1.5초를 넘지 않는다**(스펙 7.3). 건너뛸 수 없다 — 90초에 한 번이다.
- **소환석은 유물과 나눠 쓴다.** 새 재화를 만들지 마라(스펙 5.1).
- **정령 확률표는 유물과 같다**(스펙 8.1): 종류 균등 25%, 성급 60/25/10/4/1. `relicStarChances` 를 재사용한다.
- **밸런스 숫자를 새로 발명하지 마라.** 이 계획이 주는 값만 쓰고, 전부 `BalanceConfig` 에 둔다.
- **백엔드는 건드리지 않는다.** 주인공 용화 스프라이트(백로그 D7)도 이 계획에 없다.
- 화면은 가로 고정. 레퍼런스 게임의 이름·고유명 금지.
- 주석·커밋 메시지·UI 문구는 **한국어**, 주변 코드의 말투(단정형, 짧은 문장).
- Dart lint `sort_child_properties_last` 가 켜져 있다 — `child:` 를 마지막 인자로 유지하라.
- 각 태스크 끝에서 `cd flutter && flutter analyze` 가 **0건**(info 포함), `flutter test` 가 전부 통과. **시작 기준은 313개 통과 · analyze 0건.**
- 커밋 메시지 끝에 두 줄:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th
  ```

---

## 파일 구조

| 파일 | 책임 | 이 계획에서 |
|---|---|---|
| `flutter/lib/domain/spirit.dart` | 정령 4종·보유·편성·게이지·지속 효과 | **신규** |
| `flutter/lib/domain/summon.dart` | 소환 굴리기 공용 | 정령 굴리기와 `SummonLine` 추가 |
| `flutter/lib/domain/game_state.dart` | 상태 한 덩어리 | `spirits` 필드, 공격력 패시브 |
| `flutter/lib/domain/battle_engine.dart` | 전투 루프 | 게이지·발동·화상·둔화 |
| `flutter/lib/domain/balance_config.dart` · `flutter/lib/data/balance_codec.dart` | 계수 | 정령 계수 8개 |
| `flutter/lib/domain/save_codec.dart` | 저장 | `spirits` 한 칸 |
| `flutter/lib/app/game_controller.dart` | UI 명령 | `summonSpirit`·`equipSpirit` |
| `flutter/lib/ui/summon_panel.dart` | 소환 화면 | 정령 탭을 채운다 |
| `flutter/lib/ui/hud/spirit_cutscene.dart` | 등장 컷신 | **신규** |
| `flutter/lib/ui/game_screen.dart` | 화면 | 발동을 보고 컷신을 띄운다 |

**왜 `spirit.dart` 를 따로 두는가**: `summon.dart` 는 이미 190줄이고 유물·소환석·천장을 쥐고 있다. 정령은 전투 루프와 지속 효과까지 갖고 있어 성격이 다르다. 계획 1의 판단("정령이 들어오면 그때 나눈다")대로 지금 나눈다.

**컷신 파일이 연출 파일과 따로인 이유**: 전체 리뷰가 확인했다 — `summon_flourish.dart` 의 공개 부분은 유물 전용(`pillarColorFor`·`flourishForce`)이고 공통은 private `_phase` 뿐이다. **재사용이 아니라 두 번째 구현이다.** 다만 거기서 배운 둘은 그대로 가져온다: `useSafeArea: false`, 그리고 겹치는 그림은 **한 `Align` 기준**에 얹는다.

---

### Task 1: 도메인 — 정령 4종과 상태

**Files:**
- Create: `flutter/lib/domain/spirit.dart`
- Modify: `flutter/lib/domain/balance_config.dart`, `flutter/lib/data/balance_codec.dart` (계수 8개)
- Modify: `flutter/lib/domain/game_state.dart` (`spirits` 필드)
- Modify: `flutter/lib/domain/save_codec.dart` (`'spirits'`)
- Test: `flutter/test/domain/spirit_test.dart` (신규), `flutter/test/domain/save_codec_test.dart` (추가)

**Interfaces:**
- Produces:
  - `enum SpiritId { moss, crystal, ember, frost }` — 각 값에 `label`·`color`·`effect`
  - `enum SpiritEffect { healAll, singleBig, burnAll, slowAll }`
  - `class SpiritState` — `({Map<SpiritId,int> owned, SpiritId? active, double gauge, int firedCount, double burnLeft, double slowLeft})` + `starsOf`·`activeStars`·`isReady`·`copyWith`·`toJson`·`fromJson`·`static const empty`·`static const maxStars = 5`
  - `double spiritDamageMultiplier(int stars, BalanceConfig c)` · `double spiritPassive(int stars, BalanceConfig c)`
  - `BalanceConfig.spiritGaugeSeconds`·`spiritBossGaugeRate`·`spiritDamageBase`·`spiritDamagePerStar`·`spiritPassivePerStar`·`spiritHealRatio`·`spiritBurnSeconds`·`spiritSlowSeconds`
- Task 2가 게이지를 돌리고, Task 3이 굴리고, Task 4가 그리고, Task 5가 컷신을 띄운다.

**계수 값** — 전부 `BalanceConfig` 기본값으로 넣고 `balance_codec` 폴백도 같은 값으로 맞춘다:

| 이름 | 값 | 뜻 |
|---|---|---|
| `spiritGaugeSeconds` | 90 | 게이지가 다 차는 데 걸리는 초 |
| `spiritBossGaugeRate` | 1.5 | 보스전에서 차는 속도 배수 |
| `spiritDamageBase` | 12.0 | ★1 피해 배수(평타 대비) |
| `spiritDamagePerStar` | 4.0 | 성급마다 더해지는 배수 → ★5 = 28배 |
| `spiritPassivePerStar` | 0.02 | 평소 공격력 보정 → ★5 = +10% |
| `spiritHealRatio` | 0.12 | 이끼가 회복하는 최대 체력 비율 |
| `spiritBurnSeconds` | 5.0 | 잿불의 화상이 지속되는 초 |
| `spiritSlowSeconds` | 5.0 | 서리의 둔화가 지속되는 초 |

`spiritSlowFactor` 는 **안 만든다** — 둔화 세기는 Task 2에서 `0.5` 로 고정하고 그 자리에 주석을 남긴다. 계수를 하나 더 두면 조정할 것이 늘기만 하고 이 값은 바꿀 이유가 없다.

- [ ] **Step 1: 지금 구조를 확인한다**

```bash
cd flutter
grep -n "final SummonState summon;" lib/domain/game_state.dart
grep -n "'summon'" lib/domain/save_codec.dart
grep -n "summonStonePerAttendance" lib/domain/balance_config.dart lib/data/balance_codec.dart
```

기대: `GameState` 가 `final XState x;` 로 하위 상태를 들고, `save_codec` 이 `'x': s.x.toJson()` 으로 싣고 `?? const {}` 폴백으로 읽는다. **`spirits` 도 정확히 그 모양을 따른다** — 새 방식을 발명하지 마라.

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`flutter/test/domain/spirit_test.dart` 를 만든다. `test/domain/summon_test.dart` 의 import 스타일을 따라라(패키지 이름은 `flutter/pubspec.yaml` 의 `name:`).

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/spirit.dart';

void main() {
  const config = BalanceConfig();

  group('정령 4종', () {
    test('넷이고 이름과 효과가 다 다르다', () {
      expect(SpiritId.values, hasLength(4));
      expect(SpiritId.values.map((s) => s.label).toSet(), hasLength(4));
      expect(SpiritId.values.map((s) => s.effect).toSet(), hasLength(4),
          reason: '넷이 같은 일을 하면 고를 이유가 없다');
    });

    test('이름은 스펙 4.4 그대로다', () {
      expect(SpiritId.moss.label, '이끼의 꿈');
      expect(SpiritId.crystal.label, '수정의 꿈');
      expect(SpiritId.ember.label, '잿불의 꿈');
      expect(SpiritId.frost.label, '서리의 꿈');
    });
  });

  group('상태', () {
    test('빈 상태는 편성도 게이지도 없다', () {
      expect(SpiritState.empty.active, isNull);
      expect(SpiritState.empty.gauge, 0);
      expect(SpiritState.empty.activeStars, 0);
      expect(SpiritState.empty.isReady, isFalse);
    });

    test('게이지가 1이면 준비된 것이다 — 편성이 있어야 한다', () {
      const noSpirit = SpiritState(gauge: 1);
      expect(noSpirit.isReady, isFalse, reason: '데리고 다니는 정령이 없으면 나올 것이 없다');

      const ready = SpiritState(owned: {SpiritId.moss: 2}, active: SpiritId.moss, gauge: 1);
      expect(ready.isReady, isTrue);
      expect(ready.activeStars, 2);
    });

    test('편성한 정령의 성급을 읽는다', () {
      const s = SpiritState(owned: {SpiritId.moss: 3, SpiritId.frost: 1}, active: SpiritId.frost);
      expect(s.starsOf(SpiritId.moss), 3);
      expect(s.activeStars, 1);
      expect(s.starsOf(SpiritId.ember), 0);
    });
  });

  group('세기', () {
    test('성급이 오를수록 피해가 는다', () {
      expect(spiritDamageMultiplier(1, config), config.spiritDamageBase);
      expect(spiritDamageMultiplier(5, config),
          config.spiritDamageBase + config.spiritDamagePerStar * 4);
      expect(spiritDamageMultiplier(0, config), 0, reason: '없는 정령은 피해가 없다');
    });

    test('평소 보정도 성급을 따른다', () {
      expect(spiritPassive(0, config), 0);
      expect(spiritPassive(5, config), closeTo(config.spiritPassivePerStar * 5, 1e-9));
    });
  });

  group('저장', () {
    test('싣고 내리면 그대로다', () {
      const before = SpiritState(
        owned: {SpiritId.moss: 3, SpiritId.ember: 1},
        active: SpiritId.moss,
        gauge: 0.4,
        firedCount: 7,
      );
      final after = SpiritState.fromJson(before.toJson());
      expect(after.starsOf(SpiritId.moss), 3);
      expect(after.starsOf(SpiritId.ember), 1);
      expect(after.active, SpiritId.moss);
      expect(after.gauge, closeTo(0.4, 1e-9));
      expect(after.firedCount, 7);
    });

    test('빈 json이면 빈 상태다 — 옛 저장이 열려야 한다', () {
      expect(SpiritState.fromJson(const {}).active, isNull);
      expect(SpiritState.fromJson(const {}).gauge, 0);
    });

    test('지속 효과는 저장하지 않는다 — 전투가 끝나면 사라지는 것이다', () {
      const burning = SpiritState(burnLeft: 3, slowLeft: 2);
      final after = SpiritState.fromJson(burning.toJson());
      expect(after.burnLeft, 0);
      expect(after.slowLeft, 0);
    });
  });
}
```

- [ ] **Step 3: 실패를 확인한다**

```bash
cd flutter && flutter test test/domain/spirit_test.dart 2>&1 | tail -15
```

기대: `spirit.dart` 가 없어 컴파일 실패. 통과하면 멈추고 보고하라.

- [ ] **Step 4: 계수를 더한다**

`flutter/lib/domain/balance_config.dart` 의 생성자 기본값 끝에 여덟 개를 더하고, 같은 순서로 `final` 선언도 더한다. **주변 필드가 하는 방식을 그대로 따라라.**

```dart
    this.spiritGaugeSeconds = 90,
    this.spiritBossGaugeRate = 1.5,
    this.spiritDamageBase = 12,
    this.spiritDamagePerStar = 4,
    this.spiritPassivePerStar = 0.02,
    this.spiritHealRatio = 0.12,
    this.spiritBurnSeconds = 5,
    this.spiritSlowSeconds = 5,
```

```dart
  /// 정령 게이지가 다 차는 데 걸리는 초. **60 아래로 내리지 마라** —
  /// 컷신이 매번 떠도 괜찮은 근거가 "90초에 한 번"이다(스펙 4.3).
  final double spiritGaugeSeconds;

  /// 보스전에서 게이지가 차는 속도 배수.
  final double spiritBossGaugeRate;

  /// ★1 정령의 피해 배수(평타 대비).
  final double spiritDamageBase;

  /// 성급마다 더해지는 피해 배수.
  final double spiritDamagePerStar;

  /// 평소 공격력 보정(성급당).
  final double spiritPassivePerStar;

  /// 이끼가 회복하는 최대 체력 비율.
  final double spiritHealRatio;

  /// 잿불의 화상이 지속되는 초.
  final double spiritBurnSeconds;

  /// 서리의 둔화가 지속되는 초.
  final double spiritSlowSeconds;
```

`flutter/lib/data/balance_codec.dart` 의 `balanceFromJson` 에 **폴백이 있는 `_d`/`_i` 로** 여덟 개를 더하고 `balanceToJson` 에도 여덟 개를 쓴다. **폴백 값은 위 기본값과 같아야 한다** — 서버가 아직 이 키를 안 보내므로 폴백이 실제로 쓰이는 값이다.

- [ ] **Step 5: `spirit.dart` 를 쓴다**

```dart
import 'balance_config.dart';

/// 정령이 하는 일. 넷이 서로 달라야 고를 이유가 생긴다.
enum SpiritEffect {
  /// 전체를 때리고 주인공을 회복시킨다.
  healAll,

  /// 하나만 아주 세게 때린다.
  singleBig,

  /// 전체를 때리고 화상을 남긴다.
  burnAll,

  /// 전체를 때리고 몬스터를 둔하게 만든다.
  slowAll,
}

/// 정령 4종 — 잠든 용이 꾸는 꿈의 조각이다(스펙 4.1).
///
/// 색은 그 꿈이 나온 지역의 팔레트를 따른다(GAME_DESIGN 18.3).
/// 반투명 발광체라 6색 규격 밖이다 — 이펙트 취급이다.
enum SpiritId {
  moss('이끼의 꿈', 0xFF8FBF5A, SpiritEffect.healAll),
  crystal('수정의 꿈', 0xFF4FD0C0, SpiritEffect.singleBig),
  ember('잿불의 꿈', 0xFFE0713A, SpiritEffect.burnAll),
  frost('서리의 꿈', 0xFF7FC4FF, SpiritEffect.slowAll);

  const SpiritId(this.label, this.color, this.effect);

  final String label;

  /// 지역 색. 컷신과 화면이 이 값을 쓴다.
  final int color;

  final SpiritEffect effect;
}

/// 가진 정령과 데리고 다니는 하나, 그리고 게이지.
///
/// 유물과 달리 **칸이 하나**다. 그래서 성급 상한이 ★5다 —
/// ★10까지 열면 한 마리에 몰아 넣는 것이 언제나 정답이 되어 4종을 만든 뜻이 사라진다.
class SpiritState {
  const SpiritState({
    this.owned = const {},
    this.active,
    this.gauge = 0,
    this.firedCount = 0,
    this.burnLeft = 0,
    this.slowLeft = 0,
  });

  static const empty = SpiritState();

  /// 정령 성급 상한. 유물(★10)과 다르다 — 위 주석 참조.
  static const maxStars = 5;

  /// 종류 → 성급(1~5). 없는 종류는 키가 없다.
  final Map<SpiritId, int> owned;

  /// 데리고 다니는 하나. 없으면 null.
  final SpiritId? active;

  /// 0~1. 1이 되면 나온다.
  final double gauge;

  /// 지금까지 나온 횟수. **화면이 이 값이 오르는 것을 보고 컷신을 띄운다.**
  /// 불 하나(bool)로 두면 같은 프레임에 두 번 오르거나 화면이 놓친다.
  final int firedCount;

  /// 화상이 남은 초. 저장하지 않는다 — 전투가 끝나면 사라지는 것이다.
  final double burnLeft;

  /// 둔화가 남은 초. 저장하지 않는다.
  final double slowLeft;

  int starsOf(SpiritId id) => owned[id] ?? 0;

  int get activeStars => active == null ? 0 : starsOf(active!);

  /// 게이지가 다 찼고 데리고 다니는 정령이 있다.
  bool get isReady => gauge >= 1 && active != null && activeStars > 0;

  SpiritState copyWith({
    Map<SpiritId, int>? owned,
    SpiritId? active,
    double? gauge,
    int? firedCount,
    double? burnLeft,
    double? slowLeft,
  }) =>
      SpiritState(
        owned: owned ?? this.owned,
        active: active ?? this.active,
        gauge: gauge ?? this.gauge,
        firedCount: firedCount ?? this.firedCount,
        burnLeft: burnLeft ?? this.burnLeft,
        slowLeft: slowLeft ?? this.slowLeft,
      );

  Map<String, dynamic> toJson() => {
        'owned': {for (final e in owned.entries) e.key.name: e.value},
        'active': active?.name,
        'gauge': gauge,
        'firedCount': firedCount,
      };

  factory SpiritState.fromJson(Map<String, dynamic> j) {
    final raw = j['owned'] as Map<String, dynamic>? ?? const {};
    final activeName = j['active'] as String?;
    return SpiritState(
      owned: {
        for (final id in SpiritId.values)
          if (raw[id.name] != null) id: (raw[id.name] as num).toInt(),
      },
      active: SpiritId.values.where((i) => i.name == activeName).firstOrNull,
      gauge: (j['gauge'] as num? ?? 0).toDouble(),
      firedCount: (j['firedCount'] as num? ?? 0).toInt(),
    );
  }
}

/// 정령이 나올 때의 피해 배수(평타 대비). 성급 0이면 0이다.
double spiritDamageMultiplier(int stars, BalanceConfig c) =>
    stars <= 0 ? 0 : c.spiritDamageBase + c.spiritDamagePerStar * (stars - 1);

/// 평소 공격력 보정(0~0.10).
double spiritPassive(int stars, BalanceConfig c) =>
    stars <= 0 ? 0 : c.spiritPassivePerStar * stars;
```

`firstOrNull` 은 `package:collection` 이 아니라 Dart 3의 `Iterable` 확장이다 — 이 저장소의 `monster.dart` 가 이미 쓴다. import가 필요하면 그 파일을 보고 맞춰라.

**`copyWith` 의 `active` 는 null로 되돌릴 수 없다**(`active ?? this.active`). 편성을 비우는 기능은 이 계획에 없으므로 그대로 둔다 — 필요해지면 그때 `Object?` 센티널을 쓴다. 이 사실을 `copyWith` 위 주석에 한 줄로 남겨라.

- [ ] **Step 6: `GameState` 와 저장에 칸을 낸다**

`flutter/lib/domain/game_state.dart`:
1. import에 `import 'spirit.dart';`
2. 생성자 기본값에 `this.spirits = SpiritState.empty,` — `summon` 옆에 둔다.
3. 필드:
```dart
  /// 정령 — 가진 것·데리고 다니는 하나·게이지.
  final SpiritState spirits;
```
4. `copyWith` 에 `SpiritState? spirits,` 와 `spirits: spirits ?? this.spirits,`

`flutter/lib/domain/save_codec.dart` — `'summon'` 이 실리는 방식 그대로:
```dart
      'spirits': s.spirits.toJson(),
```
```dart
      spirits: SpiritState.fromJson(j['spirits'] as Map<String, dynamic>? ?? const {}),
```

`flutter/test/domain/save_codec_test.dart` 에 한 케이스를 더한다:

```dart
  test('정령 상태가 저장에 실린다', () {
    final state = GameState.initial(const BalanceConfig()).copyWith(
      spirits: const SpiritState(owned: {SpiritId.frost: 4}, active: SpiritId.frost),
    );
    final back = decodeSave(encodeSave(state));
    expect(back.spirits.starsOf(SpiritId.frost), 4);
    expect(back.spirits.active, SpiritId.frost);
  });
```

함수 이름(`encodeSave`/`decodeSave`)은 그 파일이 실제로 쓰는 것을 확인하고 맞춰라.

- [ ] **Step 7: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, **324 통과**(313 + `spirit_test.dart` 10 + `save_codec_test.dart` 1).

- [ ] **Step 8: 커밋**

```bash
git add flutter/lib flutter/test/domain
git commit -m "feat(domain): 정령 4종과 상태 — 칸이 하나라 상한이 ★5다

이끼·수정·잿불·서리. 효과가 넷 다 달라야 고를 이유가 생긴다.

유물은 네 칸이 다 쓰이지만 정령은 한 칸이라 성급이 곧바로 힘이 된다.
★10까지 열면 한 마리에 몰아 넣는 것이 언제나 정답이 되어 4종을
만든 뜻이 사라진다. 그래서 ★5다.

화상·둔화 남은 시간은 저장하지 않는다 — 전투가 끝나면 사라지는 것이다.
발동을 bool이 아니라 횟수로 센다. 화면이 그 값이 오르는 것을 보고 컷신을 띄운다.

스펙 4.1·4.2·4.4.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 2: 전투 루프 — 게이지·발동·화상·둔화

스펙 4.2. **이 계획에서 유일하게 전투 루프를 건드리는 태스크다.**

**Files:**
- Modify: `flutter/lib/domain/battle_engine.dart` (`tick`, `_move`, 새 메서드 둘)
- Modify: `flutter/lib/domain/upgrade.dart` (`Stats.withSpirit`)
- Modify: `flutter/lib/domain/game_state.dart` (`statsWith` 사슬)
- Test: `flutter/test/domain/spirit_test.dart` (추가)

**Interfaces:**
- Consumes: Task 1의 `SpiritState`·`SpiritId`·`SpiritEffect`·`spiritDamageMultiplier`·`spiritPassive`·계수 8개
- Produces: `BattleEngine.tick` 이 게이지를 돌리고 준비되면 발동한다. `Stats withSpirit(SpiritState, BalanceConfig)`.

**어디에 무엇이 들어가나:**

| 무엇 | 어디 |
|---|---|
| 게이지 차오름 | `tick` — 주인공이 살아 있고 몬스터가 있을 때만 |
| 발동 | `tick` 의 자동 스킬 **뒤** |
| 화상 피해 | `tick` — 발동과 같은 자리에서 초당 |
| 둔화 | `_move` 의 `config.monsterMoveSpeed` 에 계수를 곱한다 |
| 평소 보정 | `Stats` 사슬 끝 |

- [ ] **Step 1: 지금 사슬과 루프를 확인한다**

```bash
cd flutter
grep -n "statsWith" lib/domain/game_state.dart
grep -n "withRelics" lib/domain/upgrade.dart
grep -n "s.skills.autoReadySlots" -B4 -A4 lib/domain/battle_engine.dart
grep -n "config.monsterMoveSpeed" lib/domain/battle_engine.dart
```

기대: `Stats.fromLevels(...).scaledBy(...).withPet(...).withRelics(...)` 사슬이 보이고, `tick` 안에 자동 스킬 루프가 있으며, `monsterMoveSpeed` 를 쓰는 곳이 `_move` 한 줄이다. **그 한 줄에 둔화 계수를 곱한다.**

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`flutter/test/domain/spirit_test.dart` 에 더한다. import에 `battle_engine.dart`·`game_state.dart`·`upgrade.dart`·`dart:math` 가 필요하다.

```dart
  group('전투 루프', () {
    BattleEngine engine() => const BattleEngine(BalanceConfig());

    // 이름을 `withSpirit` 으로 두지 마라 — 같은 파일에서 `stats.withSpirit(...)` 을 부른다.
    GameState stateWith(SpiritId id, int stars) => GameState.initial(config).copyWith(
          spirits: SpiritState(owned: {id: stars}, active: id),
        );

    test('게이지는 시간으로 찬다', () {
      var s = stateWith(SpiritId.crystal, 1);
      s = engine().tick(s, 9, Random(1));
      expect(s.spirits.gauge, closeTo(9 / config.spiritGaugeSeconds, 0.02),
          reason: '90초에 1이 되는 속도다');
    });

    test('데리고 다니는 정령이 없으면 안 찬다', () {
      var s = GameState.initial(config);
      s = engine().tick(s, 30, Random(1));
      expect(s.spirits.gauge, 0);
    });

    test('가득 차면 나오고 게이지가 0으로 돌아간다', () {
      var s = stateWith(SpiritId.crystal, 3).copyWith(
        spirits: SpiritState(owned: const {SpiritId.crystal: 3}, active: SpiritId.crystal, gauge: 0.99),
      );
      final before = s.spirits.firedCount;
      s = engine().tick(s, 2, Random(1));
      expect(s.spirits.firedCount, before + 1, reason: '화면이 이 값으로 컷신을 띄운다');
      expect(s.spirits.gauge, lessThan(0.2), reason: '나오면 0으로 돌아간다');
    });

    test('이끼는 주인공을 회복시킨다', () {
      var s = stateWith(SpiritId.moss, 3);
      final maxHp = s.maxHeroHp(config);
      s = s.copyWith(
        heroHp: maxHp * 0.3,
        spirits: SpiritState(owned: const {SpiritId.moss: 3}, active: SpiritId.moss, gauge: 1),
      );
      s = engine().tick(s, 0.1, Random(1));
      expect(s.heroHpOr(config), greaterThan(maxHp * 0.3));
    });

    test('잿불은 화상을, 서리는 둔화를 남긴다', () {
      var burn = stateWith(SpiritId.ember, 2).copyWith(
        spirits: SpiritState(owned: const {SpiritId.ember: 2}, active: SpiritId.ember, gauge: 1),
      );
      burn = engine().tick(burn, 0.1, Random(1));
      expect(burn.spirits.burnLeft, greaterThan(0));
      expect(burn.spirits.slowLeft, 0);

      var slow = stateWith(SpiritId.frost, 2).copyWith(
        spirits: SpiritState(owned: const {SpiritId.frost: 2}, active: SpiritId.frost, gauge: 1),
      );
      slow = engine().tick(slow, 0.1, Random(1));
      expect(slow.spirits.slowLeft, greaterThan(0));
      expect(slow.spirits.burnLeft, 0);
    });

    test('화상과 둔화는 시간이 지나면 사라진다', () {
      var s = stateWith(SpiritId.ember, 1).copyWith(
        spirits: const SpiritState(
            owned: {SpiritId.ember: 1}, active: SpiritId.ember, burnLeft: 1, slowLeft: 1),
      );
      s = engine().tick(s, 2, Random(1));
      expect(s.spirits.burnLeft, 0);
      expect(s.spirits.slowLeft, 0);
    });

    test('평소 보정이 공격력에 걸린다', () {
      const stats = Stats(attack: 100, attacksPerSecond: 2, critChance: 0.1, goldMultiplier: 1);
      const none = SpiritState();
      expect(stats.withSpirit(none, config).attack, 100);

      const five = SpiritState(owned: {SpiritId.moss: 5}, active: SpiritId.moss);
      expect(stats.withSpirit(five, config).attack, closeTo(100 * 1.10, 1e-6));
    });

    test('statsWith가 정령을 거친다 — 사슬에 붙어 있어야 한다', () {
      final bare = GameState.initial(config);
      final withIt = bare.copyWith(
        spirits: const SpiritState(owned: {SpiritId.moss: 5}, active: SpiritId.moss),
      );
      expect(withIt.statsWith(config).attack, greaterThan(bare.statsWith(config).attack));
    });
  });
```

**먼저 확인할 것**: 게이지는 **몬스터가 있을 때만** 찬다(Step 5). 그래서 위 테스트가 `GameState.initial(config)` 에 몬스터가 있다는 것에 기댄다. 먼저 확인하라:

```bash
cd flutter && cat > /tmp/wave_check.dart <<'DART'
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
void main() => print('wave: ${GameState.initial(const BalanceConfig()).wave.length}');
DART
dart run /tmp/wave_check.dart; rm /tmp/wave_check.dart
```

`wave: 0` 이면 테스트가 통째로 안 돈다. 그때는 각 테스트에서 `engine().tick(s, 0.1, Random(1))` 를 한 번 먼저 돌려 몬스터가 나오게 한 뒤 게이지를 재고, **그 사실을 리포트에 적어라.** 0이 아니면 그대로 진행한다.

- [ ] **Step 3: 실패를 확인한다**

```bash
cd flutter && flutter test test/domain/spirit_test.dart 2>&1 | tail -15
```

기대: `withSpirit` 이 없어 컴파일 실패, 게이지 테스트도 실패.

- [ ] **Step 4: 평소 보정을 사슬에 잇는다**

`flutter/lib/domain/upgrade.dart` — `withRelics` 바로 아래에 더한다. import에 `import 'spirit.dart';` 가 필요하다.

```dart
  /// 데리고 다니는 정령의 평소 보정. 공격력에만 걸린다 —
  /// 정령의 값어치는 평소가 아니라 나올 때다.
  Stats withSpirit(SpiritState spirits, BalanceConfig c) {
    final bonus = spiritPassive(spirits.activeStars, c);
    if (bonus == 0) return this;
    return Stats(
      attack: attack * (1 + bonus),
      attacksPerSecond: attacksPerSecond,
      critChance: critChance,
      goldMultiplier: goldMultiplier,
    );
  }
```

`flutter/lib/domain/game_state.dart` 의 `statsWith` 끝에 잇는다:

```dart
      .withSpirit(spirits, config)
```

- [ ] **Step 5: 게이지와 발동을 `tick` 에 넣는다**

`flutter/lib/domain/battle_engine.dart` — 자동 스킬 루프 **뒤**에 넣는다. import에 `import 'spirit.dart';`.

```dart
    // 정령 — 게이지가 차고, 다 차면 스스로 나온다.
    s = _spiritTick(s, stats, dt, rng);
```

메서드 둘을 더한다:

```dart
  /// 게이지를 채우고 지속 효과를 줄인다. 다 차면 정령을 부른다.
  GameState _spiritTick(GameState s, Stats stats, double dt, Random rng) {
    final sp = s.spirits;
    if (sp.active == null || sp.activeStars <= 0) return s;

    // 화상은 초당 들어간다. 둔화는 _move가 읽는다.
    var next = sp.copyWith(
      burnLeft: max(0.0, sp.burnLeft - dt),
      slowLeft: max(0.0, sp.slowLeft - dt),
    );
    if (sp.burnLeft > 0 && s.wave.isNotEmpty) {
      // 화상 총량은 한 방 피해의 절반이다. 계수를 따로 두지 않는다 —
      // 한 방 피해가 바뀌면 화상도 따라가야 맞다.
      final perSecond = stats.attack *
          spiritDamageMultiplier(sp.activeStars, config) * 0.5 / config.spiritBurnSeconds;
      s = _strike(s, stats, perSecond * dt, s.wave.length, rng);
    }

    // 몬스터가 없으면 안 찬다 — 빈 화면에서 게이지가 도는 것은 이상하다.
    if (s.wave.isNotEmpty) {
      final rate = (s.isBoss ? config.spiritBossGaugeRate : 1) / config.spiritGaugeSeconds;
      next = next.copyWith(gauge: (next.gauge + dt * rate).clamp(0.0, 1.0));
    }
    s = s.copyWith(spirits: next);

    if (!s.spirits.isReady || s.wave.isEmpty) return s;
    return _fireSpirit(s, stats, rng);
  }

  /// 정령이 나온다. 종류마다 하는 일이 다르다(스펙 4.4).
  GameState _fireSpirit(GameState s, Stats stats, Random rng) {
    final sp = s.spirits;
    final id = sp.active!;
    final damage = stats.attack * spiritDamageMultiplier(sp.activeStars, config);
    final all = s.wave.length;

    var next = sp.copyWith(gauge: 0, firedCount: sp.firedCount + 1);
    switch (id.effect) {
      case SpiritEffect.healAll:
        s = s.copyWith(
          heroHp: min(s.maxHeroHp(config),
              s.heroHpOr(config) + s.maxHeroHp(config) * config.spiritHealRatio),
        );
      case SpiritEffect.singleBig:
        break;
      case SpiritEffect.burnAll:
        next = next.copyWith(burnLeft: config.spiritBurnSeconds);
      case SpiritEffect.slowAll:
        next = next.copyWith(slowLeft: config.spiritSlowSeconds);
    }
    final targets = id.effect == SpiritEffect.singleBig ? 1 : all;
    return _strike(s.copyWith(spirits: next), stats, damage, targets, rng);
  }
```

- [ ] **Step 6: 둔화를 `_move` 에 넣는다**

`flutter/lib/domain/battle_engine.dart:155` 근처의 이 줄을 고친다:

```dart
      final (mx, my) = moveToward(m.x, m.y, tx, ty, min(config.monsterMoveSpeed * dt, gap));
```

`_move` 첫머리에서 계수를 구하고 그것을 쓴다:

```dart
    // 서리의 둔화. 계수를 따로 두지 않는다 — 바꿀 이유가 없는 값이다.
    final speed = config.monsterMoveSpeed * (s.spirits.slowLeft > 0 ? 0.5 : 1.0);
```
```dart
      final (mx, my) = moveToward(m.x, m.y, tx, ty, min(speed * dt, gap));
```

- [ ] **Step 7: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -5
```

기대: analyze 0건, **332 통과**(324 + 새 테스트 8).

**기존 전투·벽 테스트가 깨지면 그것부터 보라.** 정령이 없으면 `_spiritTick` 이 첫 줄에서 돌아가고 `withSpirit` 도 `this` 를 그대로 준다 — 깨졌다면 그 조기 반환이 빠진 것이다.

- [ ] **Step 8: 커밋**

```bash
git add flutter/lib/domain flutter/test/domain/spirit_test.dart
git commit -m "feat(domain): 정령이 전투에 나온다 — 게이지·발동·화상·둔화

게이지는 몬스터가 있을 때만 찬다. 빈 화면에서 도는 것은 이상하다.
보스전에서는 1.5배 빨리 찬다.

피해는 기존 _strike를 그대로 쓴다. 이끼는 회복, 수정은 단일,
잿불은 화상, 서리는 둔화. 둔화는 _move의 속도 한 줄에 계수를 곱한다.

정령이 없으면 조기 반환이라 기존 전투가 한 줄도 안 바뀐다.

스펙 4.2·4.4.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 3: 정령을 소환한다

스펙 8.1 — 종류 균등 25%, 성급은 유물과 같은 표. `relicStarChances` 를 재사용한다.

**Files:**
- Modify: `flutter/lib/domain/summon.dart` (`SummonLine`, `SpiritSummonResult`, `summonSpirits`)
- Modify: `flutter/lib/app/game_controller.dart` (`summonSpirit`, `equipSpirit`)
- Test: `flutter/test/domain/spirit_test.dart` (추가)

**Interfaces:**
- Consumes: Task 1의 `SpiritId`·`SpiritState`, 기존 `relicStarChances`·`mergeStars`·`SummonState`
- Produces:
  - `class SummonLine { String label; int before; int after; }` + `bool get upgraded` + `String get text`
  - `SummonResult.line` · `SpiritSummonResult.line` — 둘 다 `SummonLine` 을 준다
  - `(SummonState, SpiritState, List<SpiritSummonResult>) summonSpirits(SummonState stones, SpiritState spirits, Random rng, BalanceConfig c, {required int count})`
  - 컨트롤러: `List<SpiritSummonResult> summonSpirit({required int count})` · `void equipSpirit(SpiritId id)`

**왜 `SummonLine` 인가**: 계획 2의 연출(`showSummonFlourish`)이 `List<SummonResult>` 를 받는데 그건 유물 전용이다(`RelicSlot`). 정령도 같은 연출을 써야 하므로 **연출이 받는 모양을 한 겹 얇게** 만든다. 연출 자체는 Task 4가 고친다.

**정령 승급도 `mergeStars` 를 쓴다** — 다만 상한이 `SpiritState.maxStars`(5)다. `mergeStars` 가 `SummonState.maxStars`(10)로 묶으므로 **그대로 쓰면 ★10까지 올라간다.** `mergeStars` 에 상한 인자를 더한다:

```dart
int mergeStars({required int current, required int rolled, int cap = SummonState.maxStars}) =>
    current == 0 ? rolled : max(current + 1, rolled).clamp(1, cap);
```

기존 호출부(유물)는 인자를 안 넘기므로 안 바뀐다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`flutter/test/domain/spirit_test.dart` 에 더한다.

```dart
  group('정령 소환', () {
    test('종류는 균등하다', () {
      final rng = Random(11);
      final counts = <SpiritId, int>{};
      var stones = const SummonState(stones: 1000000);
      var spirits = SpiritState.empty;
      for (var i = 0; i < 8000; i++) {
        final (s2, sp2, r) = summonSpirits(stones, spirits, rng, config, count: 1);
        stones = s2;
        spirits = sp2;
        counts[r.single.id] = (counts[r.single.id] ?? 0) + 1;
      }
      for (final id in SpiritId.values) {
        expect(counts[id]! / 8000, closeTo(0.25, 0.03), reason: id.label);
      }
    });

    test('성급 상한이 ★5다 — 유물의 ★10이 아니다', () {
      final rng = Random(3);
      var stones = const SummonState(stones: 1000000);
      var spirits = SpiritState.empty;
      for (var i = 0; i < 500; i++) {
        final (s2, sp2, _) = summonSpirits(stones, spirits, rng, config, count: 1);
        stones = s2;
        spirits = sp2;
      }
      for (final id in SpiritId.values) {
        expect(spirits.starsOf(id), lessThanOrEqualTo(SpiritState.maxStars), reason: id.label);
      }
      expect(spirits.owned.values.any((v) => v == SpiritState.maxStars), isTrue,
          reason: '500번이면 하나는 만렙이다');
    });

    test('소환석이 모자라면 아무 일도 없다', () {
      const poor = SummonState(stones: 10);
      final (after, spirits, results) =
          summonSpirits(poor, SpiritState.empty, Random(1), config, count: 1);
      expect(results, isEmpty);
      expect(after.stones, 10);
      expect(spirits.owned, isEmpty);
    });

    test('결과 한 줄이 승급을 보여 준다', () {
      const fresh = SpiritSummonResult(id: SpiritId.moss, stars: 2, byPity: false, before: 0, after: 2);
      const up = SpiritSummonResult(id: SpiritId.frost, stars: 1, byPity: false, before: 3, after: 4);
      expect(fresh.line.text, '이끼의 꿈 ★2');
      expect(up.line.text, '서리의 꿈 ★3 → ★4');
    });

    test('상한에 닿은 정령은 승급 화살표를 안 그린다', () {
      const capped = SpiritSummonResult(
          id: SpiritId.ember, stars: 1, byPity: false,
          before: SpiritState.maxStars, after: SpiritState.maxStars);
      expect(capped.line.text, '잿불의 꿈 ★5');
    });
  });
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/domain/spirit_test.dart 2>&1 | tail -15
```

기대: `summonSpirits`·`SpiritSummonResult`·`SummonLine` 이 없어 컴파일 실패.

- [ ] **Step 3: `SummonLine` 을 만들고 유물 결과가 그것을 주게 한다**

`flutter/lib/domain/summon.dart` 에 더한다.

```dart
/// 연출이 그리는 한 줄. 유물과 정령이 같은 모양으로 넘긴다.
///
/// 연출은 무엇을 뽑았는지 몰라도 된다 — 이름과 성급 전후만 있으면 그린다.
class SummonLine {
  const SummonLine({required this.label, required this.before, required this.after});

  final String label;
  final int before;
  final int after;

  /// 이미 갖고 있던 것이었나. **상한에 닿으면 참이어도 성급이 안 오른다** —
  /// 문구는 [text] 가 `after > before` 로 판단한다.
  bool get upgraded => before > 0;

  String get text =>
      upgraded && after > before ? '$label ★$before → ★$after' : '$label ★$after';
}
```

`SummonResult` 에 게터를 더한다:

```dart
  /// 연출이 그릴 한 줄.
  SummonLine get line => SummonLine(label: slot.label, before: before, after: after);
```

기존 `summonResultLine(r)` 은 **남겨 둔다** — 화면 두 곳이 쓴다. 다만 본문을 `r.line.text` 로 바꿔 한 곳에서만 문구를 정하게 하라.

`mergeStars` 에 `cap` 인자를 더한다(위 설명대로).

- [ ] **Step 4: 정령 굴리기를 만든다**

`flutter/lib/domain/summon.dart` 끝에 더한다. import에 `import 'spirit.dart';`.

```dart
/// 정령 소환 한 건의 결과.
class SpiritSummonResult {
  const SpiritSummonResult({
    required this.id,
    required this.stars,
    required this.byPity,
    this.before = 0,
    this.after = 0,
  });

  final SpiritId id;

  /// 굴려 나온 성급. 실제로 오른 값은 [after] 다.
  final int stars;

  final bool byPity;
  final int before;
  final int after;

  SummonLine get line => SummonLine(label: id.label, before: before, after: after);
}

/// 정령을 count번 소환한다. 소환석은 유물과 같은 지갑에서 나간다(스펙 5.1).
///
/// 확률표는 유물과 같다(스펙 8.1) — 종류 균등, 성급은 [relicStarChances].
/// 천장 카운터도 소환석과 함께 [SummonState] 에 있으므로 유물과 공유한다.
(SummonState, SpiritState, List<SpiritSummonResult>) summonSpirits(
  SummonState stones,
  SpiritState spirits,
  Random rng,
  BalanceConfig c, {
  required int count,
}) {
  final cost = count == 1 ? c.summonCost : c.summonTenCost;
  if (stones.stones < cost) return (stones, spirits, const []);

  final owned = {...spirits.owned};
  final results = <SpiritSummonResult>[];
  var pity = stones.pityCount;

  for (var i = 0; i < count; i++) {
    pity += 1;
    final pityReached = pity >= c.summonPity;
    final id = SpiritId.values[rng.nextInt(SpiritId.values.length)];
    final rolled = pityReached ? maxRolledStars : _rollStars(rng);
    if (rolled >= maxRolledStars) pity = 0;

    final current = owned[id] ?? 0;
    final merged = mergeStars(current: current, rolled: rolled, cap: SpiritState.maxStars);
    owned[id] = merged;
    results.add(SpiritSummonResult(
      id: id, stars: rolled, byPity: pityReached, before: current, after: merged));
  }

  return (
    stones.copyWith(stones: stones.stones - cost, pityCount: pity),
    spirits.copyWith(owned: owned),
    results,
  );
}
```

`_rollStars(rng)` 는 지금 `rollRelic` 안에 있는 성급 추첨을 **작은 private 함수로 뽑아낸 것**이다. `rollRelic` 도 그것을 쓰게 고쳐라 — 표를 두 번 적으면 갈라진다.

- [ ] **Step 5: 컨트롤러에 명령을 낸다**

`flutter/lib/app/game_controller.dart` — 기존 `summonRelic` 이 어떻게 상태를 바꾸는지 보고 그 방식을 그대로 따라라.

```dart
  /// 정령을 count번 소환한다. 소환석이 모자라면 빈 목록.
  List<SpiritSummonResult> summonSpirit({required int count}) {
    final (stones, spirits, results) =
        summonSpirits(state.summon, state.spirits, _rng, _config, count: count);
    if (results.isEmpty) return const [];
    state = state.copyWith(summon: stones, spirits: spirits);
    return results;
  }

  /// 데리고 다닐 정령을 고른다. 안 가진 것은 못 고른다.
  void equipSpirit(SpiritId id) {
    if (state.spirits.starsOf(id) <= 0) return;
    state = state.copyWith(spirits: state.spirits.copyWith(active: id));
  }
```

`_config` 의 실제 이름은 이 파일에서 확인하고 맞춰라(`summonRelic` 이 쓰는 것과 같다).

- [ ] **Step 6: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, **337 통과**(332 + 새 테스트 5).

유물 소환 테스트가 깨지면 `mergeStars` 의 `cap` 기본값이나 `_rollStars` 추출이 잘못된 것이다.

- [ ] **Step 7: 커밋**

```bash
git add flutter/lib flutter/test/domain/spirit_test.dart
git commit -m "feat(domain): 정령을 소환한다 — 같은 지갑, 같은 확률표

소환석과 천장을 유물과 나눠 쓴다. 확률표도 같다. 다만 상한이 ★5라
mergeStars에 cap 인자를 더했다 — 유물 호출부는 안 바뀐다.

연출이 받을 모양을 SummonLine 한 겹으로 얇게 만들었다. 연출은
무엇을 뽑았는지 몰라도 이름과 성급 전후만 있으면 그린다.

스펙 5.1·8.1.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 4: 소환 화면의 정령 탭

지금 정령 탭은 `Center(child: PixelText('정령 — 준비 중'))` 한 줄이다. 이걸 채운다.

**Files:**
- Modify: `flutter/lib/ui/summon_panel.dart` (정령 탭)
- Modify: `flutter/lib/ui/hud/summon_flourish.dart` (`List<SummonLine>` 을 받게)
- Test: `flutter/test/ui/summon_flourish_test.dart`, `flutter/test/ui/game_screen_test.dart`

**Interfaces:**
- Consumes: Task 3의 `SummonLine`·`SpiritSummonResult`·컨트롤러 명령 둘
- Produces: `showSummonFlourish(BuildContext, List<SummonLine>)` — 유물과 정령이 같은 연출을 쓴다

**화면 모양** — 유물 탭과 같은 `PopupTwoPane` 문법이다:

```
│   데리고 다니는 것      │   나온 것       │
│   ─────────            │   ─────────     │
│  [이끼의 꿈 ★3] ←편성  │  [서리 ★1]     │
│   수정의 꿈 ★1         │                 │
│   잿불의 꿈 —          │  ★5까지 37회   │
│   서리의 꿈 ★2         │   소환석 240    │
│                        │ [1회] [10회]   │
```

- 왼쪽 단: 4종을 다 보여 준다. **안 가진 것은 흐리게 `—`** 로. 가진 것을 누르면 편성이 바뀐다. 편성된 것은 금색 테두리.
- 왼쪽 단에 일괄 버튼은 **없다**(유물 탭과 같은 이유 — 고를 것이 편성뿐이고 그건 탭으로 한다).
- 오른쪽 단은 유물 탭과 같은 모양이다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`flutter/test/ui/game_screen_test.dart` 끝에 더한다.

```dart
  testWidgets('정령 탭에 4종이 다 보이고 안 가진 것은 흐리다', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await tester.tap(find.text('소환').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('정령').first);
    await tester.pumpAndSettle();

    for (final label in ['이끼의 꿈', '수정의 꿈', '잿불의 꿈', '서리의 꿈']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('정령 — 준비 중'), findsNothing, reason: '이제 자리가 채워졌다');
    expect(find.text('1회'), findsWidgets);
    expect(find.text('10회'), findsWidgets);
  });
```

`flutter/test/ui/summon_flourish_test.dart` 의 기존 테스트들이 `SummonResult` 를 넘기는데 이제 `SummonLine` 을 받는다. **기존 테스트를 고치되 단언은 그대로 둬라** — 예를 들어:

```dart
      await open(tester, const [SummonLine(label: '뿔', before: 0, after: 5)]);
      ...
      expect(find.text('뿔 ★5'), findsWidgets);
```

그리고 정령도 같은 연출을 쓰는지 한 줄 더한다:

```dart
    testWidgets('정령도 같은 연출을 쓴다', (tester) async {
      await open(tester, const [SummonLine(label: '서리의 꿈', before: 3, after: 4)]);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.text('서리의 꿈 ★3 → ★4'), findsWidgets);
    });
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/ui/ 2>&1 | tail -15
```

기대: 정령 탭이 '준비 중'이라 첫 테스트가 실패하고, 연출이 아직 `SummonResult` 를 받아 컴파일 실패.

- [ ] **Step 3: 연출이 `SummonLine` 을 받게 한다**

`flutter/lib/ui/hud/summon_flourish.dart`:
- `showSummonFlourish(BuildContext context, List<SummonLine> lines)` 로 바꾼다.
- `_SummonFlourish`·`SummonResultLine` 도 `SummonLine` 을 받는다. `SummonResultLine` 은 `line.text` 를 그리고 `line.upgraded && line.after > line.before` 로 금색을 정한다.
- **기둥 색은 굴린 값**이었는데 `SummonLine` 에는 그 값이 없다. `showSummonFlourish` 에 `required int topStars` 를 인자로 더한다 — 호출부가 굴린 값의 최고를 계산해 넘긴다. 이렇게 두면 연출은 무엇을 뽑았는지 몰라도 된다.

`flutter/lib/ui/summon_panel.dart` 의 유물 `_summon` 을 새 서명에 맞춘다:

```dart
    showSummonFlourish(context, [for (final r in results) r.line],
        topStars: results.map((r) => r.stars).reduce(math.max));
```

`dart:math` import가 필요하면 더해라.

- [ ] **Step 4: 정령 탭을 채운다**

`flutter/lib/ui/summon_panel.dart` — 유물 탭이 쓰는 `PopupTwoPane` 문법을 그대로 따라라. **새 문법을 발명하지 마라.**

담을 것:
- 왼쪽 `PopupPane`: `SpiritId.values` 를 돌며 한 줄씩. 가진 것은 `★N`, 안 가진 것은 `—`(`PixelPalette.textDim`). 편성된 것은 `PixelPanel(border: PixelPalette.gold)`. 가진 것을 누르면 `controller.equipSpirit(id)`. `action` 은 안 넘긴다.
- 오른쪽 `PopupPane`: 방금 나온 결과(`List<SpiritSummonResult>` 를 `setState` 로 들고 있는다), 천장 카운터, 소환석 잔량, `action` 에 `1회`·`10회`.
- 소환하면 `showSummonFlourish(context, [for (final r in results) r.line], topStars: ...)`.
- 정령 이름 색은 `Color(id.color)` 를 쓴다.

- [ ] **Step 5: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -5
```

기대: analyze 0건, **339 통과**(337 + 새 테스트 2).

- [ ] **Step 6: 커밋**

```bash
git add flutter/lib flutter/test/ui
git commit -m "feat(flutter): 정령 탭 — 4종을 보여 주고 하나를 데리고 다닌다

안 가진 것도 자리를 보여 준다. 무엇이 있는지 알아야 뽑을 이유가 생긴다.
편성은 눌러서 바꾼다.

연출이 SummonLine을 받게 해서 유물과 정령이 같은 연출을 쓴다.
기둥 색만 호출부가 굴린 값을 넘긴다 — 연출은 무엇을 뽑았는지 모른다.

스펙 4.2·6절.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

### Task 5: 등장 컷신과 문서

스펙 7.3. **1.5초를 넘지 않고 건너뛸 수 없다** — 90초에 한 번이고 이게 이 게임에서 제일 화려한 순간이다.

**Files:**
- Create: `flutter/lib/ui/hud/spirit_cutscene.dart`
- Modify: `flutter/lib/ui/game_screen.dart` (`ref.listen` 에 한 갈래)
- Modify: `docs/superpowers/specs/2026-09-05-summon-design.md`, `docs/BACKLOG.md`
- Test: `flutter/test/ui/spirit_cutscene_test.dart` (신규)

**Interfaces:**
- Consumes: Task 1의 `SpiritId`·`SpiritState.firedCount`
- Produces: `Future<void> showSpiritCutscene(BuildContext context, SpiritId id)`

**계획 2에서 가져오는 둘**: `useSafeArea: false`(안 그러면 노치 자리가 안 어두워진다), 그리고 겹치는 그림은 **한 `Align` 기준**에 얹는다(안 그러면 화면 크기에 따라 어긋난다). 나머지는 **두 번째 구현**이다 — 연출 파일을 재사용하려 들지 마라.

**시간표** (총 1.4초, 상한 1.5초 안):

| 구간 | t | 무엇 |
|---|---|---|
| 어두워짐 | 0.00~0.15 | 배경이 검게 |
| 등장 | 0.15~0.45 | 정령 색 원이 가운데서 커진다 (반투명 발광체) |
| 이름 | 0.30~0.70 | 정령 이름이 뜬다 |
| 사라짐 | 0.70~1.00 | 원이 커지며 옅어진다 |

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`flutter/test/ui/spirit_cutscene_test.dart` 를 만든다.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/spirit.dart';
import 'package:idle_fantasy/ui/hud/spirit_cutscene.dart';

void main() {
  Future<void> open(WidgetTester tester, SpiritId id) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSpiritCutscene(context, id),
          child: const Text('열기'),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump();
  }

  testWidgets('정령 이름이 뜬다', (tester) async {
    await open(tester, SpiritId.frost);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('서리의 꿈'), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('1.5초 안에 스스로 닫힌다 — 건너뛸 수 없다', (tester) async {
    await open(tester, SpiritId.moss);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(SpiritGlow), findsOneWidget);

    // 탭해도 안 닫힌다.
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(find.byType(SpiritGlow), findsOneWidget, reason: '건너뛸 수 없다(스펙 7.3)');

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.byType(SpiritGlow), findsNothing, reason: '스스로 닫힌다');
  });

  testWidgets('정령마다 색이 다르다', (tester) async {
    for (final id in [SpiritId.moss, SpiritId.crystal]) {
      await open(tester, id);
      await tester.pump(const Duration(milliseconds: 400));
      final glow = tester.widget<SpiritGlow>(find.byType(SpiritGlow));
      expect(glow.color, Color(id.color), reason: id.label);
      await tester.pumpAndSettle();
    }
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd flutter && flutter test test/ui/spirit_cutscene_test.dart 2>&1 | tail -15
```

기대: `spirit_cutscene.dart` 가 없어 컴파일 실패.

- [ ] **Step 3: 컷신을 만든다**

`flutter/lib/ui/hud/spirit_cutscene.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/spirit.dart';
import 'pixel_ui.dart';

/// 정령이 나오는 순간의 컷신. **1.5초를 넘지 않고 건너뛸 수 없다**(스펙 7.3) —
/// 90초에 한 번이고, 이게 이 게임에서 제일 화려한 순간이다.
///
/// 계획 2의 소환 연출과 파일이 다른 이유: 그쪽 공개 부분은 유물 전용이고
/// 공통은 private 하나뿐이다. 재사용이 아니라 두 번째 구현이다.
Future<void> showSpiritCutscene(BuildContext context, SpiritId id) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent, // 어둡게는 컷신이 직접 한다
    barrierDismissible: false, // 건너뛸 수 없다
    useSafeArea: false, // 노치 자리도 어두워져야 한다
    builder: (_) => _SpiritCutscene(id: id),
  );
}

/// 반투명 발광체. 6색 규격 밖이다 — 이펙트 취급이다(스펙 4.1).
class SpiritGlow extends StatelessWidget {
  const SpiritGlow({super.key, required this.progress, required this.color, required this.fade});

  /// 0~1. 커지는 정도.
  final double progress;

  final Color color;

  /// 0~1. 1이면 다 사라진 것이다.
  final double fade;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        height: 220,
        child: CustomPaint(painter: _GlowPainter(progress, color, fade)),
      );
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.progress, this.color, this.fade);

  final double progress;
  final Color color;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    // 사라질 때는 더 커지면서 옅어진다.
    final r = size.width / 2 * (0.3 + 0.7 * progress + 0.4 * fade);
    final alpha = (1 - fade).clamp(0.0, 1.0);

    // 바깥 무리와 안쪽 심지. 반투명이라 겹칠수록 밝아 보인다.
    canvas.drawCircle(center, r, Paint()..color = color.withValues(alpha: 0.22 * alpha));
    canvas.drawCircle(center, r * 0.62, Paint()..color = color.withValues(alpha: 0.38 * alpha));
    canvas.drawCircle(center, r * 0.3, Paint()..color = color.withValues(alpha: 0.7 * alpha));
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.progress != progress || old.color != color || old.fade != fade;
}

/// 구간 [from, to] 안에서 0~1로 흐르는 값.
double _phase(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

class _SpiritCutscene extends StatefulWidget {
  const _SpiritCutscene({required this.id});

  final SpiritId id;

  @override
  State<_SpiritCutscene> createState() => _SpiritCutsceneState();
}

class _SpiritCutsceneState extends State<_SpiritCutscene> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..forward().whenComplete(_close);

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.id.color);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final dim = _phase(t, 0, 0.15);
        final grow = Curves.easeOutCubic.transform(_phase(t, 0.15, 0.45));
        final fade = _phase(t, 0.70, 1.0);
        final nameOn = t >= 0.30 && t < 0.85;

        return SizedBox.expand(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.72 * dim * (1 - fade)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (grow > 0) SpiritGlow(progress: grow, color: color, fade: fade),
                if (nameOn)
                  Align(
                    alignment: const Alignment(0, 0.45),
                    child: PixelText(widget.id.label, size: 16, color: color),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: 화면이 발동을 보고 띄우게 한다**

`flutter/lib/ui/game_screen.dart` 의 `ref.listen(gameControllerProvider, (before, after) {...})` 안에 한 갈래를 더한다. 보스 경고·패배 안내가 이미 그 자리에 있다.

```dart
      // 정령이 나온 순간에만 컷신을 띄운다. 횟수가 오른 것으로 안다 —
      // 게이지를 보면 프레임마다 흔들리고, bool은 놓친다.
      if (before != null && after.spirits.firedCount > before.spirits.firedCount) {
        final id = after.spirits.active;
        if (id != null) showSpiritCutscene(context, id);
      }
```

import에 `import 'hud/spirit_cutscene.dart';` 를 더한다.

- [ ] **Step 5: 스펙과 백로그에 적는다**

`docs/superpowers/specs/2026-09-05-summon-design.md` 4.2절의 마지막 항목 뒤에 한 문단:

```markdown
**2026-09-05 구현 뒤**: 정령 성급 상한은 **★5**로 정했다(4.2가 계획 3에 남긴 결정). 유물은 네 칸이 다 쓰이지만
정령은 한 칸이라 성급이 곧바로 힘이 된다 — ★10까지 열면 한 마리에 몰아 넣는 것이 언제나 정답이 되어 4종을 만든 뜻이 사라진다.
게이지는 **몬스터가 있을 때만** 찬다. 빈 화면에서 도는 것은 이상하다.
```

7.3절 끝에 한 문단:

```markdown
**2026-09-05 구현 뒤**: 컷신은 `lib/ui/hud/spirit_cutscene.dart` 이고 총 **1.4초**다 —
어두워짐 0.15 · 등장 0.15~0.45 · 이름 0.30~0.85 · 사라짐 0.70~1.00. 탭해도 안 닫히고 스스로 끝난다.
**소환 연출과 파일이 다르다** — 그쪽 공개 부분은 유물 전용이라 재사용이 아니라 두 번째 구현이다.
```

11절 끝에 한 줄:

```markdown
**계획 3 완료 시점(2026-09-05)**: 정령 축까지. 스펙 전체가 구현됐다. 남은 것은 주인공 용화 스프라이트(백로그 D7)와
연출 마무리(D9 잔여: 화면 흔들림·스케일 팝), 그리고 정령 확장 6종(4.4의 "나머지 6지역은 확장 자리다")이다.
```

`docs/BACKLOG.md` 의 `### D9.` 뒤에:

```markdown
### D10. 정령을 10종으로 · M
지금 4종(숲·동굴·화산·설원)이다. 스펙 4.4가 "나머지 6지역은 확장 자리다"라고 남겼다 —
늪지·사막·심해·하늘섬·폐허·마계. 효과가 겹치지 않아야 고를 이유가 생기므로, 지금 있는 넷
(회복·단일·화상·둔화) 밖의 것을 찾아야 한다. 아트는 반투명 발광체라 6색 규격 밖이고
색만 지역 팔레트를 따르면 되므로 몸통 스프라이트보다 싸다.
```

- [ ] **Step 6: 테스트와 정적 분석**

```bash
cd flutter && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -3
```

기대: analyze 0건, **342 통과**(339 + 새 테스트 3).

- [ ] **Step 7: 커밋**

```bash
git add flutter/lib flutter/test/ui/spirit_cutscene_test.dart docs
git commit -m "feat(flutter): 정령 등장 컷신 — 1.4초, 건너뛸 수 없다

90초에 한 번이라 매번 떠도 화면을 안 망친다. 그래서 건너뛰기가 없다.
반투명 발광체가 커졌다가 이름을 남기고 옅어진다.

화면은 발동 횟수가 오르는 것을 보고 띄운다. 게이지를 보면 프레임마다
흔들리고 bool은 놓친다.

소환 연출과 파일이 다르다 — 그쪽 공개 부분은 유물 전용이라
재사용이 아니라 두 번째 구현이다.

스펙 7.3. 백로그 D10(정령 10종).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017f4M3d46u19kG6LomXX2th"
```

---

## 이 계획이 하지 않는 것

- **정령을 10종으로 늘리지 않는다.** 4종으로 시작한다(스펙 4.4, 백로그 D10).
- **주인공 용화 스프라이트를 안 그린다**(백로그 D7).
- **연출 마무리를 안 한다** — 화면 흔들림·스케일 팝은 백로그 D9 잔여다.
- **설정의 "연출 생략"을 안 만든다** — 설정 화면이 3등급이다(백로그 D8).
- **밸런스를 다시 안 잡는다.** 정령 계수는 이 계획이 주는 초기값을 쓰고, 조정은 플레이 뒤에 한다.
- **백엔드를 안 건드린다.** 서버는 정령을 모른다 — 유물과 같은 상황이다(백로그 D6-1).

## 알려진 위험

| 위험 | 어디서 터지나 | 대응 |
|---|---|---|
| 정령이 없는 상태에서 기존 전투 테스트가 깨진다 | Task 2 Step 7 | `_spiritTick` 이 첫 줄에서 조기 반환하고 `withSpirit` 도 `this` 를 그대로 준다. 깨졌다면 그 둘이 빠진 것이다 |
| `mergeStars` 에 `cap` 을 더해 유물 호출부가 바뀐다 | Task 3 Step 3 | 기본값이 `SummonState.maxStars` 라 안 바뀐다. 유물 테스트가 그대로 통과해야 한다 |
| 연출이 `SummonLine` 을 받게 되며 기존 테스트가 다 깨진다 | Task 4 Step 2 | 의도한 것이다. **단언은 그대로 두고 입력만 바꿔라** — 기대 문구가 바뀌면 무언가 잘못된 것이다 |
| 컷신이 전투 중에 뜨는데 팝업이 이미 떠 있다 | Task 5 Step 4 | `showDialog` 는 쌓인다. 소환 화면을 보는 중에 정령이 나오면 컷신이 그 위에 뜬다 — 1.4초 뒤 스스로 닫히므로 갇히지 않는다. 그대로 둔다 |
| 컷신이 `barrierDismissible: false` 라 안드로이드 뒤로 가기로도 안 닫힌다 | Task 5 Step 3 | 스스로 닫히므로 갇히지 않는다. 다만 뒤로 가기가 먹히는지 리포트에 적어라 |
| 게이지가 도는 동안 화면이 안 보여 준다 | Task 4 | 이 계획은 게이지 표시를 안 만든다. 유저는 정령이 언제 나올지 모른다 — **리포트에 적고 백로그 후보로 남겨라** |
