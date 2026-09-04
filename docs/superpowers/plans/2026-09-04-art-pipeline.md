# 아트 파이프라인 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PixelLab 픽셀 스프라이트 시트를 Flame 무대에 올려 무리 전투 화면을 그리는 파이프라인을 만들고, 그 전에 스파이크로 도구·화풍·타격감을 검증한다.

**Architecture:** 무대는 가상 해상도 360×270의 Flame `World` + `CameraComponent.withFixedResolution`. 배경 2레이어 → 액터(y 정렬, 단일 `Actor` 클래스) → 이펙트 → 표시 순으로 쌓고, 전부를 흔들림 루트가 감싼다. 도메인은 Flame을 모르며, 화면 계층이 `GameState` 변화를 `StageEvent` 목록으로 바꿔 무대에 단방향으로 밀어 넣는다. 스프라이트는 "PNG 가로 스트립 + JSON" 쌍이고, 로더가 id별로 캐시한다.

**Tech Stack:** Flutter 3.x / Dart ^3.12, flame ^1.38.2, flutter_riverpod ^3.4, Python 3 + Pillow(에셋 변환 스크립트), PixelLab MCP(HTTP), 이미지 생성 모델(배경).

**Spec:** `docs/superpowers/specs/2026-09-03-art-pipeline-design.md`

## Global Constraints

> **스파이크(2026-09-04)에서 갱신된 규칙** — 아래 태스크 본문보다 이 항목이 우선한다.
> - 주인공·동료 프레임은 **56×56**(표준 모드 캔버스 68에 키 50px). 몬스터 48, 펫 32, 보스 96은 그대로.
> - 묶인 시트는 항상 오른쪽을 본다. 주인공은 서쪽 뷰 + `--flip`, 몬스터는 동쪽 뷰. 앱은 적만 반전.
> - 배경은 PixelLab `create_image_pixflux` 360×272로 뽑아 `bg_pixelize.py`로 나눈다. 외부 이미지 모델 불필요.
> - `BattleStageGame`은 `FlameGame` 기본 `world`/`camera`를 쓰고(생성자 `camera:`), `camera.viewfinder.anchor = Anchor.topLeft`.
> - 백플래시는 `renderTree`+`saveLayer`가 아니라 스프라이트 페인트 `ColorFilter.mode(white, srcATop)`. Task 9·13의 코드는 이 규칙대로 고쳐 쓴다.
> - PixelLab MCP는 사용자 설정(`claude mcp add -s user`)에 등록. 저장소에 `.mcp.json` 없음.
> - 헤드리스 캡처는 `onLoad()` 직접 호출이 아니라 `GameWidget` + `game.ready()` + `RepaintBoundary`(`test/spike/spike_capture_test.dart` 참고).

- 가상 해상도 **360×270** 픽셀 단위, 4:3 고정. 기기 폭에 맞춰 통째로 확대.
- 확대는 최근접 보간(`FilterQuality.none`, `isAntiAlias = false`). 액터 위치는 정수 픽셀로 반올림.
- 스프라이트 크기: 캐릭터·일반 몬스터 **48×48**, 새끼 용 **32×32**, 보스 **96×96**, 아이템 아이콘 **32×32**.
- 방향은 동쪽 1개만 생성, 서쪽은 좌우 반전.
- 애니메이션 세트 5종 고정: `idle`(4) `walk`(6) `attack`(6) `hit`(2) `death`(6). 누락 시 로드 실패.
- 파일: `assets/sprites/<group>/<id>.png` + `.json`, group ∈ `hero` `pet` `monster` `boss`. 배경 `assets/backgrounds/<regionId>/far.png` `ground.png`. 이펙트 `assets/vfx/<id>.png` + `.json`. 아이콘 `assets/icons/items/<id>.png`.
- 도메인(`lib/domain/**`)은 Flame을 import하지 않는다. 무대는 엔진 상태를 읽지 않고 이벤트만 받는다.
- 스파이크 코드(`lib/spike/**`)는 파이프라인 구현 후 삭제한다.
- 모든 명령은 `flutter/` 디렉터리에서 실행한다. 커밋 메시지는 한국어, 기존 형식(`feat(flutter): …`).
- 스파이크 합격 판정(Task 6)은 사용자가 실기기 캡처를 보고 내린다. 합격 전에는 Phase B(Task 7~)를 시작하지 않는다.

---

## File Structure

**Phase A — 스파이크 (버림)**
- `.mcp.json` (저장소 루트) — PixelLab MCP 서버 등록. 토큰은 환경 변수.
- `flutter/tools/requirements.txt`, `flutter/tools/sheet_pack.py` — 프레임 PNG 폴더 → 스트립 PNG + JSON.
- `flutter/tools/bg_pixelize.py` — 배경 1장 → 픽셀화 → far/ground 분리.
- `flutter/assets/sprites/**`, `flutter/assets/backgrounds/forest/**`, `flutter/assets/vfx/**` — 스파이크 에셋 (합격하면 그대로 파이프라인 에셋이 된다).
- `flutter/lib/spike/spike_stage_game.dart`, `flutter/lib/spike_main.dart` — 목업 무대와 실행 진입점.
- `ART_GUIDE.md` — 판정 기록.

**Phase B — 파이프라인**
- `flutter/lib/ui/stage/sheet_spec.dart` — JSON 파싱·검증 (순수 Dart).
- `flutter/lib/ui/stage/sheet_loader.dart` — 이미지 로드·캐시, `LoadedSheet`, 대체 시트.
- `flutter/lib/ui/stage/hue_filter.dart` — 팔레트 스왑 ColorFilter.
- `flutter/lib/ui/stage/actor_state.dart` — 상태 기계 (순수 Dart).
- `flutter/lib/ui/stage/actor.dart` — 액터 Flame 컴포넌트.
- `flutter/lib/ui/stage/formation.dart` — 진형 슬롯 (순수 Dart).
- `flutter/lib/ui/stage/stage_event.dart` — 이벤트 타입.
- `flutter/lib/ui/stage/state_diff.dart` — `GameState` 변화 → 이벤트 목록 (순수 Dart).
- `flutter/lib/ui/stage/background_layers.dart` — 배경 2레이어·패럴랙스.
- `flutter/lib/ui/stage/battle_stage_game.dart` — 무대 (전면 재작성).
- `flutter/lib/ui/battle_area.dart` — 무대 위젯 (이벤트 브리지로 수정).
- `flutter/lib/ui/skill_bar.dart` — 스킬 바 자리 (버튼 4개, 비활성).
- `flutter/lib/ui/tabs/upgrade_tab.dart` `party_tab.dart` `equipment_tab.dart` `codex_tab.dart` — 탭 내용.
- `flutter/lib/ui/game_screen.dart` — 탭 골격.
- `flutter/lib/ui/sprites/monster_sprite.dart` — 시트 기반으로 교체. `hero_painter.dart` `dragon_painter.dart` 삭제.
- 테스트: `flutter/test/ui/stage/*_test.dart`, `flutter/test/ui/game_screen_test.dart`, `flutter/test/ui/art_gallery_test.dart` 갱신.

---

# Phase A — 스파이크

### Task 1: PixelLab MCP 연결

**Files:**
- Create: `.mcp.json` (저장소 루트)
- Modify: `.gitignore` (변경 없음 — 토큰은 파일에 없음)

**Interfaces:**
- Produces: MCP 도구 `create_character`, `animate_character`가 세션에서 호출 가능.

- [ ] **Step 1: 사용자 준비 확인**

pixellab.ai 가입 후 API 토큰을 받아 셸 환경에 넣는다 (사용자 작업).

```bash
# ~/.zshrc 에 추가
export PIXELLAB_API_TOKEN="발급받은 토큰"
```

- [ ] **Step 2: `.mcp.json` 작성**

```json
{
  "mcpServers": {
    "pixellab": {
      "type": "http",
      "url": "https://api.pixellab.ai/mcp",
      "headers": {
        "Authorization": "Bearer ${PIXELLAB_API_TOKEN}"
      }
    }
  }
}
```

- [ ] **Step 3: 세션 재시작 후 연결 확인**

Claude Code를 재시작하고 `/mcp` 를 입력해 `pixellab` 서버가 connected로 보이는지 확인한다. 도구 목록에 `create_character`, `animate_character`가 있어야 한다. 실패하면 `echo $PIXELLAB_API_TOKEN` 으로 변수가 비어 있지 않은지 본다.

- [ ] **Step 4: 커밋**

```bash
git add .mcp.json
git commit -m "chore: PixelLab MCP 서버 등록 (토큰은 환경 변수)"
```

---

### Task 2: 에셋 변환 스크립트 (프레임 폴더 → 스트립 + JSON)

**Files:**
- Create: `flutter/tools/requirements.txt`
- Create: `flutter/tools/sheet_pack.py`
- Test: 수동 (샘플 프레임으로 실행)

**Interfaces:**
- Produces: `python3 tools/sheet_pack.py <프레임 루트> <출력 경로(확장자 없이)> --size 48` → `<출력>.png`(가로 스트립) + `<출력>.json`(Global Constraints의 JSON 형식). 프레임 루트 아래에 `idle/ walk/ attack/ hit/ death/` 폴더가 있고 각 폴더의 PNG를 파일명 순으로 프레임으로 쓴다.

- [ ] **Step 1: 의존성 파일**

`flutter/tools/requirements.txt`:

```
pillow==11.*
```

설치:

```bash
python3 -m venv tools/.venv && tools/.venv/bin/pip install -r tools/requirements.txt
```

- [ ] **Step 2: 스크립트 작성**

`flutter/tools/sheet_pack.py`:

```python
#!/usr/bin/env python3
"""프레임 PNG 폴더를 가로 스트립 PNG + JSON 으로 묶는다.

사용: sheet_pack.py <프레임 루트> <출력 경로(확장자 없음)> --size 48 [--fps 8]
프레임 루트/idle/*.png, walk/*.png, attack/*.png, hit/*.png, death/*.png 가 있어야 한다.
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ANIMS = ["idle", "walk", "attack", "hit", "death"]


def load_frames(folder: Path, size: int) -> list[Image.Image]:
    files = sorted(folder.glob("*.png"))
    if not files:
        sys.exit(f"프레임 없음: {folder}")
    frames = []
    for f in files:
        im = Image.open(f).convert("RGBA")
        if im.size != (size, size):
            # 원본이 더 크면 최근접으로 줄인다(픽셀 보존). 작으면 중앙 정렬.
            canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            if im.width > size or im.height > size:
                im = im.resize((size, size), Image.NEAREST)
            canvas.paste(im, ((size - im.width) // 2, size - im.height))
            im = canvas
        frames.append(im)
    return frames


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("root")
    p.add_argument("out")
    p.add_argument("--size", type=int, required=True)
    p.add_argument("--fps", type=int, default=8)
    a = p.parse_args()

    root = Path(a.root)
    all_frames: list[Image.Image] = []
    ranges: dict[str, list[int]] = {}
    for name in ANIMS:
        frames = load_frames(root / name, a.size)
        start = len(all_frames)
        all_frames.extend(frames)
        ranges[name] = [start, len(all_frames) - 1]

    strip = Image.new("RGBA", (a.size * len(all_frames), a.size), (0, 0, 0, 0))
    for i, fr in enumerate(all_frames):
        strip.paste(fr, (i * a.size, 0))
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    strip.save(out.with_suffix(".png"))
    out.with_suffix(".json").write_text(
        json.dumps({"frame": [a.size, a.size], "fps": a.fps, "animations": ranges}, indent=2)
    )
    print(f"{out.with_suffix('.png')}  frames={len(all_frames)}  {ranges}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: 샘플로 검증**

```bash
mkdir -p /tmp/sp/{idle,walk,attack,hit,death}
tools/.venv/bin/python - <<'EOF'
from PIL import Image
import itertools
for anim, n in [("idle",4),("walk",6),("attack",6),("hit",2),("death",6)]:
    for i in range(n):
        Image.new("RGBA",(48,48),(200,50+i*20,50,255)).save(f"/tmp/sp/{anim}/{i:02d}.png")
EOF
tools/.venv/bin/python tools/sheet_pack.py /tmp/sp /tmp/sp_out/sample --size 48
```

Expected: `/tmp/sp_out/sample.png frames=24 {'idle': [0, 3], 'walk': [4, 9], 'attack': [10, 15], 'hit': [16, 17], 'death': [18, 23]}`. `file /tmp/sp_out/sample.png` 가 `1152 x 48` 이어야 한다.

- [ ] **Step 4: 커밋**

```bash
git add tools/requirements.txt tools/sheet_pack.py
git commit -m "chore(flutter): 스프라이트 시트 묶기 스크립트 (프레임 폴더 → 스트립+JSON)"
```

`tools/.venv/` 는 커밋하지 않는다 (`.gitignore`에 `flutter/tools/.venv/` 추가 후 같이 커밋).

---

### Task 3: 스파이크 캐릭터 생성 (화풍 앵커 + 시트 6개)

**Files:**
- Create: `flutter/assets/sprites/hero/warrior_1.png` `.json`, `warrior_2.png` `.json`
- Create: `flutter/assets/sprites/pet/fire_baby.png` `.json` (32px)
- Create: `flutter/assets/sprites/monster/forest_1.png` `.json`, `forest_2.png` `.json`
- Create: `flutter/assets/sprites/boss/forest.png` `.json` (96px)
- Modify: `ART_GUIDE.md` (화풍 앵커 프롬프트·이미지 기록)

**Interfaces:**
- Produces: 위 시트 6쌍. JSON은 Task 2 형식.

- [ ] **Step 1: 화풍 앵커 뽑기**

`create_character` 를 같은 설명으로 4회 호출한다(도구 파라미터 이름은 세션의 도구 스키마를 그대로 따른다). 공통 조건: 크기 48, 8방향, 투명 배경.

설명(영문):

```
small brave knight kid, brown messy hair, blue tunic, round wooden shield on left arm, short sword,
chibi 2-head proportion, big eyes, thick dark outline, flat colors with one-step shading,
pixel art game sprite, side view facing right, transparent background
```

4장의 동쪽 프레임을 `ART_GUIDE.md` 아래 `## 스파이크 기록` 절에 파일명과 함께 적고, **사용자가 하나를 고른다**. 고른 캐릭터 id를 이후 모든 호출의 스타일 참조로 쓴다(PixelLab이 참조 캐릭터 id를 받으면 그 파라미터로, 아니면 같은 프롬프트 접두어로).

- [ ] **Step 2: 시트 6개 생성**

각 캐릭터마다 `create_character` 1회 + `animate_character` 로 `idle` `walk` `attack` `hit` `death` 를 요청한다. 동쪽 방향만 내려받아 `tools/frames/<id>/<anim>/NN.png` 에 둔다.

| id | 크기 | 설명 |
|---|---|---|
| hero/warrior_1 | 48 | 앵커 그대로 |
| hero/warrior_2 | 48 | 앵커 + `steel plate armor, red cape, longer sword, small crest on helmet` (1차 전직) |
| pet/fire_baby | 32 | `tiny baby dragon, red-orange scales, stubby wings, big eyes, wisps of smoke, facing right` |
| monster/forest_1 | 48 | `round green slime blob with a tiny leaf on top, happy expression, facing left` |
| monster/forest_2 | 48 | `chubby blue frog with big cheeks, facing left` |
| boss/forest | 96 | `ancient tree guardian golem made of mossy bark, kind old face, glowing eyes, imposing, facing left` |

몬스터·보스는 서쪽을 바라보게 그리는 대신 **동쪽으로 뽑고 앱에서 반전**한다(Global Constraints). 설명의 `facing left`는 참고용이며 PixelLab 방향 파라미터는 east로 고정.

- [ ] **Step 3: 스트립으로 묶기**

```bash
V=tools/.venv/bin/python
$V tools/sheet_pack.py tools/frames/warrior_1 assets/sprites/hero/warrior_1 --size 48
$V tools/sheet_pack.py tools/frames/warrior_2 assets/sprites/hero/warrior_2 --size 48
$V tools/sheet_pack.py tools/frames/fire_baby assets/sprites/pet/fire_baby --size 32
$V tools/sheet_pack.py tools/frames/forest_1 assets/sprites/monster/forest_1 --size 48
$V tools/sheet_pack.py tools/frames/forest_2 assets/sprites/monster/forest_2 --size 48
$V tools/sheet_pack.py tools/frames/forest assets/sprites/boss/forest --size 96
```

Expected: 6개 모두 `frames=24` 이고 애니메이션 범위가 `idle [0,3] walk [4,9] attack [10,15] hit [16,17] death [18,23]`. PixelLab 템플릿의 프레임 수가 다르면 그 수가 JSON에 그대로 들어가므로 무방하다. 다만 5종이 모두 있어야 한다.

- [ ] **Step 4: 크레딧 기록**

PixelLab 대시보드에서 사용 크레딧을 읽어 `ART_GUIDE.md` 스파이크 기록 절에 "시트 6개 = N 크레딧, 43시트 예상 = N×43/6" 으로 적는다.

- [ ] **Step 5: 커밋**

```bash
git add assets/sprites ../ART_GUIDE.md
git commit -m "art: 스파이크 스프라이트 시트 6종 (PixelLab, 전사·1차·아기용·숲 몬스터 2·숲 보스)"
```

`tools/frames/` 는 커밋하지 않는다 (`.gitignore`에 `flutter/tools/frames/` 추가).

---

### Task 4: 숲 배경 1장과 이펙트 1개

**Files:**
- Create: `flutter/tools/bg_pixelize.py`
- Create: `flutter/assets/backgrounds/forest/far.png`, `ground.png`
- Create: `flutter/assets/vfx/slash_circle.png` `.json`, `flutter/assets/vfx/hit_spark.png` `.json`
- Modify: `ART_GUIDE.md` (배경 프롬프트, VFX 출처·라이선스)

**Interfaces:**
- Produces: `bg_pixelize.py <입력.png> <출력 폴더> --horizon 110` → `far.png`(360×110) + `ground.png`(360×160). VFX JSON은 애니메이션 이름이 `play` 하나뿐인 변형 (아래 형식).

- [ ] **Step 1: 배경 스크립트**

`flutter/tools/bg_pixelize.py`:

```python
#!/usr/bin/env python3
"""배경 이미지 1장을 360×270 픽셀화하고 지평선에서 far/ground 로 나눈다.

사용: bg_pixelize.py <입력.png> <출력 폴더> --horizon 110 [--colors 32]
"""
import argparse
from pathlib import Path

from PIL import Image

W, H = 360, 270


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("out_dir")
    p.add_argument("--horizon", type=int, default=110)
    p.add_argument("--colors", type=int, default=32)
    a = p.parse_args()

    im = Image.open(a.src).convert("RGB")
    # 4:3 으로 중앙 크롭 후 축소
    ratio = W / H
    w, h = im.size
    if w / h > ratio:
        nw = int(h * ratio)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / ratio)
        im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    im = im.resize((W, H), Image.NEAREST)
    im = im.quantize(colors=a.colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")

    out = Path(a.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    im.crop((0, 0, W, a.horizon)).save(out / "far.png")
    im.crop((0, a.horizon, W, H)).save(out / "ground.png")
    print(f"far {W}x{a.horizon}, ground {W}x{H - a.horizon} → {out}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: 배경 생성·변환**

이미지 모델에 다음 프롬프트로 1장을 뽑아 `tools/frames/bg_forest.png` 에 둔다.

```
pixel art game background, 3/4 top-down view of a forest clearing, grassy ground plane with perspective,
tree line on the horizon, a few rocks and mushrooms, soft daylight, 16-bit style, no characters, no text
```

```bash
tools/.venv/bin/python tools/bg_pixelize.py tools/frames/bg_forest.png assets/backgrounds/forest --horizon 110
```

Expected: `far 360x110, ground 360x160`. 지평선 위치가 그림과 안 맞으면 `--horizon` 값을 바꿔 다시 돌린다.

- [ ] **Step 3: 이펙트 2개**

itch.io에서 CC0 픽셀 이펙트 팩(예: pimen "Slash Effect", "Hit Spark") 을 내려받아 라이선스 파일을 확인하고, 프레임을 `tools/frames/vfx_slash/play/`, `tools/frames/vfx_spark/play/` 에 둔다. VFX는 애니메이션이 `play` 하나이므로 `sheet_pack.py` 대신 아래 한 줄 스크립트로 묶는다.

```bash
V=tools/.venv/bin/python
$V - <<'EOF'
import json, sys
from pathlib import Path
from PIL import Image
for name, size in [("vfx_slash", 64), ("vfx_spark", 32)]:
    files = sorted(Path(f"tools/frames/{name}/play").glob("*.png"))
    frames = [Image.open(f).convert("RGBA").resize((size, size), Image.NEAREST) for f in files]
    strip = Image.new("RGBA", (size * len(frames), size))
    for i, fr in enumerate(frames): strip.paste(fr, (i * size, 0))
    out = Path("assets/vfx") / name.replace("vfx_", {"vfx_slash": "slash_circle", "vfx_spark": "hit_spark"}[name])
    out.parent.mkdir(parents=True, exist_ok=True)
    strip.save(out.with_suffix(".png"))
    out.with_suffix(".json").write_text(json.dumps({"frame": [size, size], "fps": 16, "animations": {"play": [0, len(frames) - 1]}}))
    print(out, len(frames))
EOF
```

`ART_GUIDE.md` 스파이크 기록 절에 팩 이름·URL·라이선스를 적는다.

- [ ] **Step 4: 커밋**

```bash
git add tools/bg_pixelize.py assets/backgrounds assets/vfx ../ART_GUIDE.md
git commit -m "art: 숲 배경 2레이어 + 픽셀 VFX 2종 (스파이크)"
```

---

### Task 5: 스파이크 목업 무대

**Files:**
- Create: `flutter/lib/spike/spike_stage_game.dart`
- Create: `flutter/lib/spike_main.dart`
- Modify: `flutter/pubspec.yaml` (assets 등록)

**Interfaces:**
- Consumes: Task 3·4 에셋. `FloatingDamage` (`lib/ui/stage/battle_stage_game.dart`, 기존).
- Produces: `flutter run -t lib/spike_main.dart` 로 실기기에서 도는 목업. 버림 코드.

- [ ] **Step 1: pubspec 에셋 등록**

`flutter/pubspec.yaml`의 `assets:` 를 다음으로 바꾼다.

```yaml
  assets:
    - assets/monsters.json
    - assets/sprites/hero/
    - assets/sprites/pet/
    - assets/sprites/monster/
    - assets/sprites/boss/
    - assets/backgrounds/forest/
    - assets/vfx/
```

- [ ] **Step 2: 목업 무대 작성**

`flutter/lib/spike/spike_stage_game.dart`:

```dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../ui/stage/battle_stage_game.dart' show FloatingDamage;

/// 스파이크 전용 목업. 시트 6개를 360×270 무대에 세우고 자동 공격 루프를 돈다. 버림 코드.
class SpikeStageGame extends FlameGame {
  final _images = Images(prefix: 'assets/');
  final _world = World();
  late final _root = _ShakeRoot();
  late final _actors = _ActorLayer();
  final _rng = math.Random();
  final _pixel = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  final _enemies = <_Actor>[];
  late _Actor _hero;
  double _clock = 0;
  double _hitStop = 0;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    final cam = CameraComponent.withFixedResolution(width: 360, height: 270, world: _world);
    await addAll([_world, cam]);
    await _world.add(_root);

    _root.add(SpriteComponent(sprite: await _sprite('backgrounds/forest/far.png'), position: Vector2.zero(), paint: _pixel));
    _root.add(SpriteComponent(sprite: await _sprite('backgrounds/forest/ground.png'), position: Vector2(0, 110), paint: _pixel));
    _root.add(_actors);

    _hero = await _actor('hero/warrior_1', 48, Vector2(96, 190), facingRight: true);
    _actors.addAll([
      _hero,
      await _actor('pet/fire_baby', 32, Vector2(66, 202), facingRight: true),
    ]);
    for (final (id, size, pos) in [
      ('monster/forest_1', 48, Vector2(250, 168)),
      ('monster/forest_2', 48, Vector2(280, 190)),
      ('monster/forest_1', 48, Vector2(256, 214)),
      ('boss/forest', 96, Vector2(310, 200)),
    ]) {
      final a = await _actor(id, size, pos, facingRight: false, hue: id.endsWith('_1') && pos.y > 200 ? 120 : 0);
      _enemies.add(a);
      _actors.add(a);
    }
  }

  Future<Sprite> _sprite(String path) async => Sprite(await _images.load(path));

  Future<_Actor> _actor(String id, int size, Vector2 pos, {required bool facingRight, double hue = 0}) async {
    final image = await _images.load('sprites/$id.png');
    final spec = jsonDecode(await rootBundle.loadString('assets/sprites/$id.json')) as Map<String, dynamic>;
    return _Actor(image: image, spec: spec, size: size, pos: pos, facingRight: facingRight, hue: hue, pixel: _pixel);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitStop > 0) {
      _hitStop -= dt;
      _actors.timeScale = _hitStop > 0 ? 0 : 1;
    }
    _clock += dt;
    if (_clock >= 0.9) {
      _clock = 0;
      _hero.play('attack');
      final target = _enemies[_rng.nextInt(_enemies.length)];
      Future<void>.delayed(const Duration(milliseconds: 250), () => _strike(target));
    }
    for (final c in _root.children.whereType<FloatingDamage>().toList()) {
      if (c.expired) _root.remove(c);
    }
  }

  void _strike(_Actor target) {
    final crit = _rng.nextDouble() < 0.3;
    target.play('hit');
    target.flash();
    _hitStop = crit ? 0.08 : 0.05;
    _actors.timeScale = 0;
    _root.shake(crit ? 6 : 3);
    _root.add(FloatingDamage(text: crit ? '1.2K' : '553', crit: crit, start: target.pos + Vector2(_rng.nextDouble() * 20 - 10, -target.sizePx * 0.8)));
    _root.add(ParticleSystemComponent(
      position: target.pos + Vector2(0, -target.sizePx / 2),
      particle: Particle.generate(
        count: 10,
        lifespan: 0.4,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * (60 + _rng.nextDouble() * 60),
            acceleration: Vector2(0, 200),
            child: CircleParticle(radius: 1.5, paint: Paint()..color = Colors.orangeAccent),
          );
        },
      ),
    ));
  }
}

class _ShakeRoot extends PositionComponent {
  double _left = 0, _amp = 0;
  void shake(double amp) { _left = 0.3; _amp = amp; }
  @override
  void update(double dt) {
    super.update(dt);
    if (_left <= 0) { position.setZero(); return; }
    _left -= dt;
    final t = 1 - _left / 0.3;
    position.setValues(math.sin(t * math.pi * 8) * (1 - t) * _amp, 0);
  }
}

class _ActorLayer extends PositionComponent with HasTimeScale {}

class _Actor extends PositionComponent {
  _Actor({required this.image, required this.spec, required int size, required this.pos, required bool facingRight, required double hue, required this.pixel})
      : sizePx = size.toDouble(),
        _flip = facingRight ? 1 : -1,
        _paint = Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false
          ..colorFilter = hue == 0 ? null : _hueFilter(hue),
        super(anchor: Anchor.bottomCenter);

  final Image image;
  final Map<String, dynamic> spec;
  final double sizePx;
  final Vector2 pos;
  final double _flip;
  final Paint _paint;
  final Paint pixel;
  late final Map<String, SpriteAnimation> _anims;
  late final SpriteAnimationComponent _sprite;
  double _flash = 0;

  @override
  Future<void> onLoad() async {
    final fw = (spec['frame'] as List)[0] as int;
    final fps = spec['fps'] as int;
    final total = (spec['animations'] as Map).values.map((r) => (r as List)[1] as int).reduce(math.max) + 1;
    _anims = {
      for (final e in (spec['animations'] as Map<String, dynamic>).entries)
        e.key: SpriteAnimation.fromFrameData(
          image,
          SpriteAnimationData.range(
            start: (e.value as List)[0] as int,
            end: (e.value as List)[1] as int,
            amount: total,
            stepTimes: List.filled((e.value as List)[1] - (e.value as List)[0] + 1, 1 / fps),
            textureSize: Vector2.all(fw.toDouble()),
            loop: e.key == 'idle' || e.key == 'walk',
          ),
        ),
    };
    _sprite = SpriteAnimationComponent(animation: _anims['idle'], size: Vector2.all(sizePx), anchor: Anchor.bottomCenter, paint: _paint);
    add(_sprite);
    scale.x = _flip;
  }

  void play(String name) {
    final a = _anims[name]!..reset();
    _sprite.animation = a;
    if (!a.loop) a.onComplete = () => _sprite.animation = _anims['idle'];
  }

  void flash() => _flash = 0.12;

  @override
  void update(double dt) {
    super.update(dt);
    position.setValues(pos.x.roundToDouble(), pos.y.roundToDouble());
    priority = pos.y.round();
    if (_flash > 0) _flash -= dt;
  }

  @override
  void render(Canvas canvas) {
    // 발밑 그림자 (자식보다 먼저 그려진다)
    canvas.drawOval(Rect.fromCenter(center: Offset(0, 0), width: sizePx * 0.7, height: sizePx * 0.18), Paint()..color = Colors.black.withValues(alpha: 0.35));
  }

  @override
  void renderTree(Canvas canvas) {
    if (_flash <= 0) { super.renderTree(canvas); return; }
    final rect = Rect.fromLTWH(-sizePx / 2, -sizePx, sizePx, sizePx);
    canvas.saveLayer(rect, Paint());
    super.renderTree(canvas);
    canvas.drawRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.7)..blendMode = BlendMode.srcATop);
    canvas.restore();
  }
}

ColorFilter _hueFilter(double degrees) {
  final r = degrees * math.pi / 180, c = math.cos(r), s = math.sin(r);
  const lr = 0.213, lg = 0.715, lb = 0.072;
  return ColorFilter.matrix([
    lr + c * (1 - lr) - s * lr, lg - c * lg - s * lg, lb - c * lb + s * (1 - lb), 0, 0,
    lr - c * lr + s * 0.143, lg + c * (1 - lg) + s * 0.140, lb - c * lb - s * 0.283, 0, 0,
    lr - c * lr - s * (1 - lr), lg - c * lg + s * lg, lb + c * (1 - lb) + s * lb, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}
```

- [ ] **Step 3: 진입점**

`flutter/lib/spike_main.dart`:

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'spike/spike_stage_game.dart';

/// `flutter run -t lib/spike_main.dart` — 아트 스파이크 목업. 무대만 4:3으로 띄운다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          AspectRatio(aspectRatio: 4 / 3, child: GameWidget(game: SpikeStageGame())),
          const Expanded(child: Center(child: Text('스파이크 — 아래는 비어 있음', style: TextStyle(color: Colors.white54)))),
        ]),
      ),
    ),
  ));
}
```

- [ ] **Step 4: 빌드·실행**

```bash
flutter analyze lib/spike
flutter run -t lib/spike_main.dart -d <실기기 id>
```

Expected: 숲 배경 위에 전사·아기 용(왼쪽), 슬라임 2(하나는 색이 다름)·개구리·나무 보스(오른쪽)가 서 있고 0.9초마다 전사가 공격, 무작위 몬스터가 백플래시·히트스톱·데미지 숫자·불꽃 파티클과 함께 맞는다. `flutter run` 콘솔에서 `P` 키로 성능 오버레이를 켜 60fps를 확인한다.

- [ ] **Step 5: 캡처 5장**

실기기에서 스크린샷: ① 대기(화풍 앵커 확인) ② 무리 배치 전체 ③ 피격 순간(백플래시+숫자) ④ 보스 근접 ⑤ 팔레트 스왑 슬라임 두 마리 비교. `docs/superpowers/specs/captures/2026-09-spike-{1..5}.png` 에 저장.

- [ ] **Step 6: 커밋**

```bash
git add pubspec.yaml lib/spike lib/spike_main.dart ../docs/superpowers/specs/captures
git commit -m "spike(flutter): 픽셀 시트 무리 전투 목업 무대 + 실기기 캡처"
```

---

### Task 6: 판정 게이트

**Files:**
- Modify: `ART_GUIDE.md`

- [ ] **Step 1: 판정표 작성**

사용자가 캡처 5장과 실기기를 보고 아래 표를 채운다. 제가 대신 채우지 않는다.

| # | 기준 | 판정 | 근거 |
|---|---|---|---|
| 1 | 픽셀 확대가 깨끗하다 | 합/불 | |
| 2 | 시트 6개가 같은 화풍 | 합/불 | |
| 3 | 타격감 60fps | 합/불 | 성능 오버레이 수치 |
| 4 | 팔레트 스왑이 먹힌다 | 합/불 | |
| 5 | 크레딧이 43시트 예산 안 | 합/불 | Task 3 Step 4 수치 |

- [ ] **Step 2: 결과 기록**

`ART_GUIDE.md` 의 `## 4. 결정 기록` 에 날짜와 판정표를 추가한다. 전부 합격이면 1~3장을 스펙 1장의 픽셀 규격으로 전면 교체한다(512px 카툰 규격·AI 프롬프트 절 삭제, 픽셀 규격·PixelLab 프롬프트 접두어·VFX 출처로 대체). 불합격이면 스펙 2장의 분기(2 실패 → 도구 교체, 3 실패 → 엔진 재논의)를 기록하고 **여기서 멈춘다**.

- [ ] **Step 3: 커밋**

```bash
git add ../ART_GUIDE.md
git commit -m "docs: 아트 스파이크 판정 기록"
```

---

# Phase B — 파이프라인 구현 (Task 6 전부 합격 후)

### Task 7: 시트 스펙 파싱과 로더

**Files:**
- Create: `flutter/lib/ui/stage/sheet_spec.dart`
- Create: `flutter/lib/ui/stage/sheet_loader.dart`
- Test: `flutter/test/ui/stage/sheet_spec_test.dart`, `flutter/test/ui/stage/sheet_loader_test.dart`

**Interfaces:**
- Produces:
  - `class SheetSpec { int frameWidth, frameHeight, fps; Map<String, (int start, int end)> animations; int get frameCount; factory SheetSpec.fromJson(Map<String,dynamic>, {List<String> required = SheetSpec.actorAnimations}); }`
  - `const List<String> SheetSpec.actorAnimations = ['idle','walk','attack','hit','death']`
  - `class LoadedSheet { ui.Image image; SheetSpec spec; SpriteAnimation animation(String name, {required bool loop}); }`
  - `class SheetLoader { Future<LoadedSheet> load(String group, String id); Future<LoadedSheet> loadOrFallback(String group, String id, {required int size, required Color color}); static LoadedSheet fallback({required int size, required Color color}); }`

- [ ] **Step 1: 스펙 테스트**

`flutter/test/ui/stage/sheet_spec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/stage/sheet_spec.dart';

void main() {
  final ok = {
    'frame': [48, 48],
    'fps': 8,
    'animations': {'idle': [0, 3], 'walk': [4, 9], 'attack': [10, 15], 'hit': [16, 17], 'death': [18, 23]},
  };

  test('정상 JSON을 읽고 프레임 수를 계산한다', () {
    final s = SheetSpec.fromJson(ok);
    expect(s.frameWidth, 48);
    expect(s.fps, 8);
    expect(s.animations['attack'], (10, 15));
    expect(s.frameCount, 24);
  });

  test('필수 애니메이션이 빠지면 FormatException', () {
    final j = Map<String, dynamic>.from(ok)..['animations'] = {'idle': [0, 3]};
    expect(() => SheetSpec.fromJson(j), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('walk'))));
  });

  test('start > end 이면 FormatException', () {
    final j = Map<String, dynamic>.from(ok)..['animations'] = {...ok['animations'] as Map, 'hit': [17, 16]};
    expect(() => SheetSpec.fromJson(j), throwsFormatException);
  });

  test('VFX는 play 하나만 요구할 수 있다', () {
    final s = SheetSpec.fromJson({'frame': [64, 64], 'fps': 16, 'animations': {'play': [0, 7]}}, required: const ['play']);
    expect(s.frameCount, 8);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/ui/stage/sheet_spec_test.dart`
Expected: 컴파일 실패 (`sheet_spec.dart` 없음).

- [ ] **Step 3: 스펙 구현**

`flutter/lib/ui/stage/sheet_spec.dart`:

```dart
/// 스프라이트 시트 JSON. PNG 가로 스트립과 쌍이다.
///
/// ```json
/// {"frame": [48, 48], "fps": 8, "animations": {"idle": [0, 3], "walk": [4, 9], ...}}
/// ```
class SheetSpec {
  const SheetSpec({required this.frameWidth, required this.frameHeight, required this.fps, required this.animations});

  static const actorAnimations = ['idle', 'walk', 'attack', 'hit', 'death'];

  final int frameWidth;
  final int frameHeight;
  final int fps;

  /// 이름 → (시작 프레임, 끝 프레임). 끝 포함.
  final Map<String, (int, int)> animations;

  int get frameCount => animations.values.map((r) => r.$2).reduce((a, b) => a > b ? a : b) + 1;

  factory SheetSpec.fromJson(Map<String, dynamic> j, {List<String> required = actorAnimations}) {
    final frame = j['frame'] as List;
    final raw = j['animations'] as Map<String, dynamic>;
    for (final name in required) {
      if (!raw.containsKey(name)) throw FormatException('애니메이션 누락: $name');
    }
    final anims = <String, (int, int)>{};
    for (final e in raw.entries) {
      final r = e.value as List;
      final start = (r[0] as num).toInt(), end = (r[1] as num).toInt();
      if (start < 0 || start > end) throw FormatException('잘못된 범위: ${e.key} [$start, $end]');
      anims[e.key] = (start, end);
    }
    return SheetSpec(
      frameWidth: (frame[0] as num).toInt(),
      frameHeight: (frame[1] as num).toInt(),
      fps: (j['fps'] as num).toInt(),
      animations: anims,
    );
  }
}
```

- [ ] **Step 4: 스펙 테스트 통과**

Run: `flutter test test/ui/stage/sheet_spec_test.dart`
Expected: 4 tests passed.

- [ ] **Step 5: 로더 테스트**

`flutter/test/ui/stage/sheet_loader_test.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/stage/sheet_loader.dart';
import 'package:idle_fantasy/ui/stage/sheet_spec.dart';

Future<ui.Image> stripImage(int frames, int size) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  for (var i = 0; i < frames; i++) {
    canvas.drawRect(Rect.fromLTWH(i * size.toDouble(), 0, size.toDouble(), size.toDouble()), Paint()..color = Color(0xFF000000 | (i * 10)));
  }
  return rec.endRecording().toImage(frames * size, size);
}

void main() {
  test('animation()은 범위대로 프레임을 잘라 낸다', () async {
    final spec = SheetSpec.fromJson({
      'frame': [48, 48], 'fps': 8,
      'animations': {'idle': [0, 3], 'walk': [4, 9], 'attack': [10, 15], 'hit': [16, 17], 'death': [18, 23]},
    });
    final sheet = LoadedSheet(await stripImage(24, 48), spec);
    final atk = sheet.animation('attack', loop: false);
    expect(atk.frames.length, 6);
    expect(atk.frames.first.sprite.srcPosition, Vector2(480, 0));
    expect(atk.frames.first.stepTime, closeTo(1 / 8, 1e-9));
    expect(atk.loop, isFalse);
  });

  test('fallback은 5종 애니메이션이 모두 프레임 0을 가리킨다', () {
    final sheet = SheetLoader.fallback(size: 48, color: Colors.green);
    for (final name in SheetSpec.actorAnimations) {
      expect(sheet.animation(name, loop: true).frames.length, 1, reason: name);
    }
    expect(sheet.image.width, 48);
  });
}
```

- [ ] **Step 6: 로더 구현**

`flutter/lib/ui/stage/sheet_loader.dart`:

```dart
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'sheet_spec.dart';

/// 로드된 시트 = 이미지 + 스펙. 애니메이션은 호출 때마다 새로 만든다(컴포넌트마다 재생 위치가 다르다).
class LoadedSheet {
  LoadedSheet(this.image, this.spec);

  final ui.Image image;
  final SheetSpec spec;

  SpriteAnimation animation(String name, {required bool loop}) {
    final (start, end) = spec.animations[name] ?? (throw ArgumentError('애니메이션 없음: $name'));
    return SpriteAnimation.fromFrameData(
      image,
      SpriteAnimationData.range(
        start: start,
        end: end,
        amount: spec.frameCount,
        stepTimes: List.filled(end - start + 1, 1 / spec.fps),
        textureSize: Vector2(spec.frameWidth.toDouble(), spec.frameHeight.toDouble()),
        loop: loop,
      ),
    );
  }
}

/// `assets/sprites/<group>/<id>.png` + `.json` 을 읽고 id별로 캐시한다.
class SheetLoader {
  SheetLoader({Images? images, AssetBundle? bundle})
      : _images = images ?? Images(prefix: 'assets/sprites/'),
        _bundle = bundle ?? rootBundle;

  final Images _images;
  final AssetBundle _bundle;
  final _cache = <String, LoadedSheet>{};

  Future<LoadedSheet> load(String group, String id, {List<String> required = SheetSpec.actorAnimations}) async {
    final key = '$group/$id';
    final hit = _cache[key];
    if (hit != null) return hit;
    final json = jsonDecode(await _bundle.loadString('assets/sprites/$key.json')) as Map<String, dynamic>;
    final spec = SheetSpec.fromJson(json, required: required);
    final image = await _images.load('$key.png');
    return _cache[key] = LoadedSheet(image, spec);
  }

  /// 에셋이 아직 없으면(3단계 물량 생성 중) 단색 실루엣으로 대신한다. 로그만 남기고 죽지 않는다.
  Future<LoadedSheet> loadOrFallback(String group, String id, {required int size, required Color color}) async {
    try {
      return await load(group, id);
    } on Object catch (e) {
      debugPrint('시트 없음 $group/$id — 대체 실루엣: $e');
      return _cache['$group/$id'] = fallback(size: size, color: color);
    }
  }

  static LoadedSheet fallback({required int size, required Color color}) {
    final rec = ui.PictureRecorder();
    final s = size.toDouble();
    Canvas(rec).drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.15, s * 0.1, s * 0.7, s * 0.9), Radius.circular(s * 0.25)), Paint()..color = color);
    final image = rec.endRecording().toImageSync(size, size);
    return LoadedSheet(
      image,
      SheetSpec(frameWidth: size, frameHeight: size, fps: 1, animations: {for (final n in SheetSpec.actorAnimations) n: (0, 0)}),
    );
  }
}
```

- [ ] **Step 7: 로더 테스트 통과**

Run: `flutter test test/ui/stage/`
Expected: 6 tests passed.

- [ ] **Step 8: 커밋**

```bash
git add lib/ui/stage/sheet_spec.dart lib/ui/stage/sheet_loader.dart test/ui/stage
git commit -m "feat(flutter): 스프라이트 시트 스펙 파싱 + 로더(캐시·대체 실루엣)"
```

---

### Task 8: 팔레트 스왑 필터와 액터 상태 기계

**Files:**
- Create: `flutter/lib/ui/stage/hue_filter.dart`
- Create: `flutter/lib/ui/stage/actor_state.dart`
- Test: `flutter/test/ui/stage/hue_filter_test.dart`, `flutter/test/ui/stage/actor_state_test.dart`

**Interfaces:**
- Produces:
  - `List<double> hueRotationMatrix(double degrees)` (5×4 = 20개), `ColorFilter hueRotation(double degrees)`
  - `enum ActorState { idle, walk, attack, hit, death }`
  - `class ActorStateMachine { ActorState state; bool transition(ActorState next); ActorState onAnimationComplete(); }`
  - `bool ActorState.loops` (idle·walk만 true)

- [ ] **Step 1: 테스트**

`flutter/test/ui/stage/hue_filter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/stage/hue_filter.dart';

void main() {
  test('0도는 단위 행렬', () {
    final m = hueRotationMatrix(0);
    expect(m.length, 20);
    const identity = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
    for (var i = 0; i < 20; i++) {
      expect(m[i], closeTo(identity[i].toDouble(), 1e-9), reason: 'index $i');
    }
  });

  test('120도 회전은 빨강을 초록 쪽으로 옮긴다', () {
    final m = hueRotationMatrix(120);
    // 입력 (1,0,0) → 출력 R = m[0], G = m[5], B = m[10]
    expect(m[5], greaterThan(m[0]));
  });
}
```

`flutter/test/ui/stage/actor_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/stage/actor_state.dart';

void main() {
  test('idle → attack → (완료) → idle', () {
    final m = ActorStateMachine();
    expect(m.transition(ActorState.attack), isTrue);
    expect(m.state, ActorState.attack);
    expect(m.onAnimationComplete(), ActorState.idle);
  });

  test('death 이후에는 어떤 전이도 거부한다', () {
    final m = ActorStateMachine();
    expect(m.transition(ActorState.death), isTrue);
    expect(m.transition(ActorState.idle), isFalse);
    expect(m.transition(ActorState.hit), isFalse);
    expect(m.onAnimationComplete(), ActorState.death);
  });

  test('walk 완료는 walk에 머문다(루프)', () {
    final m = ActorStateMachine()..transition(ActorState.walk);
    expect(m.onAnimationComplete(), ActorState.walk);
  });

  test('loops 플래그', () {
    expect(ActorState.idle.loops, isTrue);
    expect(ActorState.walk.loops, isTrue);
    expect(ActorState.attack.loops, isFalse);
    expect(ActorState.death.loops, isFalse);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/ui/stage/hue_filter_test.dart test/ui/stage/actor_state_test.dart`
Expected: 컴파일 실패.

- [ ] **Step 3: 구현**

`flutter/lib/ui/stage/hue_filter.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

/// 색상환 회전 행렬(SVG hueRotate). 눈·외곽선이 어두우면 거의 그대로 남는다 — 팔레트 스왑의 전제.
List<double> hueRotationMatrix(double degrees) {
  final r = degrees * math.pi / 180;
  final c = math.cos(r), s = math.sin(r);
  const lr = 0.213, lg = 0.715, lb = 0.072;
  return [
    lr + c * (1 - lr) - s * lr, lg - c * lg - s * lg, lb - c * lb + s * (1 - lb), 0, 0,
    lr - c * lr + s * 0.143, lg + c * (1 - lg) + s * 0.140, lb - c * lb - s * 0.283, 0, 0,
    lr - c * lr - s * (1 - lr), lg - c * lg + s * lg, lb + c * (1 - lb) + s * lb, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

ColorFilter hueRotation(double degrees) => ColorFilter.matrix(hueRotationMatrix(degrees));
```

`flutter/lib/ui/stage/actor_state.dart`:

```dart
/// 액터 애니메이션 상태. death는 종착 상태다.
enum ActorState {
  idle,
  walk,
  attack,
  hit,
  death;

  bool get loops => this == idle || this == walk;
}

class ActorStateMachine {
  ActorState state = ActorState.idle;

  /// death 이후에는 아무것도 받지 않는다. 전이됐으면 true.
  bool transition(ActorState next) {
    if (state == ActorState.death) return false;
    state = next;
    return true;
  }

  /// 비루프 애니메이션이 끝났을 때. attack·hit는 idle로, death는 그대로.
  ActorState onAnimationComplete() {
    if (state == ActorState.attack || state == ActorState.hit) state = ActorState.idle;
    return state;
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/ui/stage/`
Expected: 12 tests passed.

- [ ] **Step 5: 커밋**

```bash
git add lib/ui/stage/hue_filter.dart lib/ui/stage/actor_state.dart test/ui/stage
git commit -m "feat(flutter): 팔레트 스왑 색상 회전 필터 + 액터 상태 기계"
```

---

### Task 9: 액터 컴포넌트

**Files:**
- Create: `flutter/lib/ui/stage/actor.dart`
- Test: `flutter/test/ui/stage/actor_test.dart`

**Interfaces:**
- Consumes: `LoadedSheet`, `SheetLoader.fallback` (Task 7), `ActorStateMachine`, `hueRotation` (Task 8).
- Produces:
  - `class Actor extends PositionComponent { Actor({required String id, required LoadedSheet sheet, required int pixelSize, required bool facingRight, double hue = 0}); final String id; final Vector2 pos; ActorState get state; void play(ActorState s); void flash(); double hpRatio; bool showHpBar; }`
  - `pos`가 진짜 위치(실수), `position`은 매 update에 정수로 반올림된 값. `priority = pos.y.round()`.

- [ ] **Step 1: 테스트**

`flutter/test/ui/stage/actor_test.dart`:

```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/stage/actor.dart';
import 'package:idle_fantasy/ui/stage/actor_state.dart';
import 'package:idle_fantasy/ui/stage/sheet_loader.dart';

void main() {
  Future<Actor> make({bool facingRight = true}) async {
    final a = Actor(id: 'hero', sheet: SheetLoader.fallback(size: 48, color: Colors.blue), pixelSize: 48, facingRight: facingRight);
    await a.onLoad();
    a.update(0);
    return a;
  }

  test('위치는 정수로 반올림되고 priority는 y', () async {
    final a = await make();
    a.pos.setValues(96.4, 190.6);
    a.update(0);
    expect(a.position, Vector2(96, 191));
    expect(a.priority, 191);
  });

  test('서쪽을 보면 scale.x가 -1', () async {
    final a = await make(facingRight: false);
    expect(a.scale.x, -1);
  });

  test('play(attack)은 상태를 바꾸고 death 이후엔 무시된다', () async {
    final a = await make();
    a.play(ActorState.attack);
    expect(a.state, ActorState.attack);
    a.play(ActorState.death);
    a.play(ActorState.idle);
    expect(a.state, ActorState.death);
  });

  test('flash는 시간이 지나면 꺼진다', () async {
    final a = await make();
    a.flash();
    expect(a.flashing, isTrue);
    a.update(0.2);
    expect(a.flashing, isFalse);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/ui/stage/actor_test.dart`
Expected: 컴파일 실패.

- [ ] **Step 3: 구현**

`flutter/lib/ui/stage/actor.dart`:

```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'actor_state.dart';
import 'hue_filter.dart';
import 'sheet_loader.dart';

/// 무대 위 캐릭터 하나. 주인공·동료·펫·몬스터·보스가 전부 이 클래스다 — 차이는 시트·크기·방향뿐.
///
/// [pos]가 진짜 위치(실수), [position]은 매 프레임 정수로 반올림된 값(픽셀 떨림 방지).
/// 앵커는 발 중앙. 깊이는 [priority] = 발 y.
class Actor extends PositionComponent {
  Actor({required this.id, required this.sheet, required this.pixelSize, required bool facingRight, double hue = 0})
      : pos = Vector2.zero(),
        _paint = Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false
          ..colorFilter = hue == 0 ? null : hueRotation(hue),
        super(anchor: Anchor.bottomCenter, size: Vector2.all(pixelSize.toDouble())) {
    scale.x = facingRight ? 1 : -1;
  }

  final String id;
  final LoadedSheet sheet;
  final int pixelSize;
  final Vector2 pos;
  final Paint _paint;
  final _machine = ActorStateMachine();
  late final Map<ActorState, SpriteAnimation> _anims;
  late final SpriteAnimationComponent _sprite;
  double _flash = 0;

  /// 발밑 소형 HP 바. 몬스터만 켠다.
  bool showHpBar = false;
  double hpRatio = 1;

  ActorState get state => _machine.state;
  bool get flashing => _flash > 0;

  @override
  Future<void> onLoad() async {
    _anims = {for (final s in ActorState.values) s: sheet.animation(s.name, loop: s.loops)};
    _sprite = SpriteAnimationComponent(
      animation: _anims[ActorState.idle],
      size: Vector2.all(pixelSize.toDouble()),
      position: Vector2(pixelSize / 2, pixelSize.toDouble()),
      anchor: Anchor.bottomCenter,
      paint: _paint,
    );
    await add(_sprite);
  }

  void play(ActorState next) {
    if (!_machine.transition(next)) return;
    final a = _anims[next]!..reset();
    _sprite.animation = a;
    if (!next.loops) {
      a.onComplete = () {
        final after = _machine.onAnimationComplete();
        if (after != next) _sprite.animation = _anims[after]!..reset();
      };
    }
  }

  void flash() => _flash = 0.12;

  @override
  void update(double dt) {
    super.update(dt);
    position.setValues(pos.x.roundToDouble(), pos.y.roundToDouble());
    priority = pos.y.round();
    if (_flash > 0) _flash -= dt;
  }

  @override
  void render(Canvas canvas) {
    // 그림자는 자식(스프라이트)보다 먼저 그려진다. 좌표계는 anchor 기준이 아니라 좌상단이다.
    final s = pixelSize.toDouble();
    canvas.drawOval(Rect.fromCenter(center: Offset(s / 2, s), width: s * 0.7, height: s * 0.18), Paint()..color = Colors.black.withValues(alpha: 0.35));
    if (showHpBar) {
      final w = s * 0.6, x = (s - w) / 2, y = s + 3;
      canvas.drawRect(Rect.fromLTWH(x, y, w, 2), Paint()..color = Colors.black54);
      canvas.drawRect(Rect.fromLTWH(x, y, w * hpRatio.clamp(0, 1), 2), Paint()..color = Colors.greenAccent);
    }
  }

  @override
  void renderTree(Canvas canvas) {
    if (_flash <= 0) {
      super.renderTree(canvas);
      return;
    }
    // 백플래시는 별도 레이어에 그려야 스프라이트 픽셀에만 칠해진다.
    final rect = Rect.fromLTWH(0, 0, pixelSize.toDouble(), pixelSize.toDouble());
    canvas.saveLayer(rect.inflate(4), Paint());
    super.renderTree(canvas);
    canvas.drawRect(rect.inflate(4), Paint()..color = Colors.white.withValues(alpha: (_flash / 0.12) * 0.7)..blendMode = BlendMode.srcATop);
    canvas.restore();
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/ui/stage/actor_test.dart`
Expected: 4 tests passed.

- [ ] **Step 5: 커밋**

```bash
git add lib/ui/stage/actor.dart test/ui/stage/actor_test.dart
git commit -m "feat(flutter): 액터 컴포넌트 (시트 애니메이션·반전·그림자·백플래시·HP 바)"
```

---

### Task 10: 진형 슬롯

**Files:**
- Create: `flutter/lib/ui/stage/formation.dart`
- Test: `flutter/test/ui/stage/formation_test.dart`

**Interfaces:**
- Produces:
  - `const stageWidth = 360.0; const stageHeight = 270.0;`
  - `const allySlots = <String, Vector2>{...}` (키 `hero` `pet` `ally1` `ally2` `ally3`)
  - `List<Vector2> enemySlots(int count)` (1~5), `final bossSlot = Vector2(300, 200)`
  - 아군 액터 id는 슬롯 키와 같다. 몬스터 id는 `mon1..mon5`, 보스는 `boss`.

- [ ] **Step 1: 테스트**

`flutter/test/ui/stage/formation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/stage/formation.dart';

void main() {
  test('아군 슬롯 5개는 무대 왼쪽 절반에 있다', () {
    expect(allySlots.keys, ['hero', 'pet', 'ally1', 'ally2', 'ally3']);
    for (final p in allySlots.values) {
      expect(p.x, lessThan(stageWidth / 2));
      expect(p.y, inInclusiveRange(150, stageHeight - 20));
    }
  });

  test('적 슬롯은 요청한 수만큼, 오른쪽 절반, y가 서로 다르다', () {
    for (var n = 1; n <= 5; n++) {
      final s = enemySlots(n);
      expect(s.length, n);
      expect(s.map((p) => p.y).toSet().length, n, reason: '깊이 겹침 n=$n');
      for (final p in s) {
        expect(p.x, greaterThan(stageWidth / 2));
      }
    }
  });

  test('6 이상은 5로 자른다', () => expect(enemySlots(9).length, 5));
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/ui/stage/formation_test.dart` → 컴파일 실패.

- [ ] **Step 3: 구현**

`flutter/lib/ui/stage/formation.dart`:

```dart
import 'package:flame/components.dart';

/// 무대 가상 해상도와 진형 슬롯(픽셀 단위, 발 위치). 3/4 필드라 y가 클수록 앞이다.
const stageWidth = 360.0;
const stageHeight = 270.0;

/// 아군: 주인공 중앙, 펫 바로 옆, 동료 3은 뒤쪽 호. 키가 곧 액터 id.
final allySlots = <String, Vector2>{
  'hero': Vector2(96, 190),
  'pet': Vector2(66, 202),
  'ally1': Vector2(54, 160),
  'ally2': Vector2(30, 186),
  'ally3': Vector2(54, 214),
};

final bossSlot = Vector2(300, 200);

const _enemyLayouts = <List<(double, double)>>[
  [(270, 190)],
  [(258, 176), (286, 204)],
  [(250, 168), (280, 190), (256, 214)],
  [(250, 168), (280, 190), (256, 214), (302, 172)],
  [(250, 168), (280, 190), (256, 214), (302, 172), (298, 222)],
];

/// 일반 몬스터 슬롯. 1~5마리, 앞뒤로 어긋나게.
List<Vector2> enemySlots(int count) =>
    [for (final (x, y) in _enemyLayouts[count.clamp(1, 5) - 1]) Vector2(x, y)];
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/ui/stage/formation_test.dart` → 3 tests passed.

- [ ] **Step 5: 커밋**

```bash
git add lib/ui/stage/formation.dart test/ui/stage/formation_test.dart
git commit -m "feat(flutter): 무대 진형 슬롯 테이블 (아군 5·몬스터 1~5·보스)"
```

---

### Task 11: 무대 이벤트와 상태 차분

**Files:**
- Create: `flutter/lib/ui/stage/stage_event.dart`
- Create: `flutter/lib/ui/stage/state_diff.dart`
- Test: `flutter/test/ui/stage/state_diff_test.dart`

**Interfaces:**
- Consumes: `GameState` (`monsterId isBoss monsterHp monsterMaxHp totalKills stage statsWith(config).attack`), `MonsterCatalog.byId/regionFor`, `BalanceConfig`.
- Produces:
  - `sealed class StageEvent`; `StageChanged(int stage, String? regionId)`, `Spawn(String actorId, int monsterId, MonsterElement element, bool isBoss, int pixelSize, double hue)`, `Attack(String actorId)`, `Hit(String targetId, double damage, bool crit, MonsterElement element, double hpRatio)`, `Death(String actorId, {bool captured})`, `Shake(double amp)`
  - `List<StageEvent> diffStageEvents(GameState? prev, GameState next, {required BalanceConfig config, required MonsterCatalog catalog})`
  - `String monsterSheetId(Monster m, MonsterCatalog catalog)` → `'<region>_<n>'` (n = 지역 내 순번 % 4 + 1), `double monsterHue(Monster m, MonsterCatalog catalog)` → 지역 내 순번 ÷ 4 × 90도.
  - 현재 1대1 엔진에서는 몬스터 액터 id가 항상 `mon1`(보스는 `boss`). 다중 타깃은 서브프로젝트 3에서 이 함수만 바꾼다.

- [ ] **Step 1: 테스트**

`flutter/test/ui/stage/state_diff_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/monster.dart';
import 'package:idle_fantasy/ui/stage/stage_event.dart';
import 'package:idle_fantasy/ui/stage/state_diff.dart';

import '../../support/catalog.dart';

void main() {
  const c = BalanceConfig();
  final base = GameState.initial(c).copyWith(stage: 3, monsterId: 1, monsterHp: 100, monsterMaxHp: 100);

  List<StageEvent> diff(GameState? prev, GameState next) => diffStageEvents(prev, next, config: c, catalog: smallCatalog);

  test('처음 상태는 StageChanged + Spawn', () {
    final ev = diff(null, base);
    expect(ev.whereType<StageChanged>().single.regionId, 'forest');
    final sp = ev.whereType<Spawn>().single;
    expect(sp.actorId, 'mon1');
    expect(sp.monsterId, 1);
    expect(sp.pixelSize, 48);
  });

  test('HP가 줄면 Attack(hero) + Hit(mon1)', () {
    final ev = diff(base, base.copyWith(monsterHp: 60));
    expect(ev.whereType<Attack>().single.actorId, 'hero');
    final hit = ev.whereType<Hit>().single;
    expect(hit.targetId, 'mon1');
    expect(hit.damage, 40);
    expect(hit.hpRatio, closeTo(0.6, 1e-9));
    expect(hit.crit, isFalse);
  });

  test('처치 후 다음 몬스터: Hit(남은 HP) + Death + Spawn', () {
    final next = base.copyWith(totalKills: base.totalKills + 1, monsterId: 2, monsterHp: 120, monsterMaxHp: 120, killsOnStage: 1);
    final ev = diff(base, next);
    expect(ev.whereType<Hit>().single.damage, 100);
    expect(ev.whereType<Death>().single.actorId, 'mon1');
    expect(ev.whereType<Spawn>().single.monsterId, 2);
  });

  test('보스 등장은 boss 액터 96px + Shake', () {
    final next = base.copyWith(isBoss: true, monsterId: 2, monsterHp: 500, monsterMaxHp: 500);
    final ev = diff(base, next);
    final sp = ev.whereType<Spawn>().single;
    expect(sp.actorId, 'boss');
    expect(sp.pixelSize, 96);
    expect(ev.whereType<Shake>(), isNotEmpty);
  });

  test('치명타는 공격력 1.5배 초과', () {
    final atk = base.statsWith(c).attack;
    final ev = diff(base.copyWith(monsterHp: 10000, monsterMaxHp: 10000), base.copyWith(monsterHp: 10000 - atk * 2, monsterMaxHp: 10000));
    expect(ev.whereType<Hit>().single.crit, isTrue);
  });

  test('시트 id와 색상은 지역 내 순번으로 정해진다', () {
    final slime = smallCatalog.byId(1)!, wolf = smallCatalog.byId(2)!;
    expect(monsterSheetId(slime, smallCatalog), 'forest_1');
    expect(monsterSheetId(wolf, smallCatalog), 'forest_2');
    expect(monsterHue(slime, smallCatalog), 0);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/ui/stage/state_diff_test.dart` → 컴파일 실패.

- [ ] **Step 3: 이벤트 타입**

`flutter/lib/ui/stage/stage_event.dart`:

```dart
import '../../domain/monster.dart';

/// 도메인 → 무대 단방향 이벤트. 무대는 이것만 보고 연출한다.
sealed class StageEvent {
  const StageEvent();
}

class StageChanged extends StageEvent {
  const StageChanged({required this.stage, required this.regionId});
  final int stage;
  final String? regionId;
}

class Spawn extends StageEvent {
  const Spawn({required this.actorId, required this.monsterId, required this.element, required this.isBoss, required this.pixelSize, required this.hue});
  final String actorId;
  final int monsterId;
  final MonsterElement element;
  final bool isBoss;
  final int pixelSize;
  final double hue;
}

class Attack extends StageEvent {
  const Attack({required this.actorId});
  final String actorId;
}

class Hit extends StageEvent {
  const Hit({required this.targetId, required this.damage, required this.crit, required this.element, required this.hpRatio});
  final String targetId;
  final double damage;
  final bool crit;
  final MonsterElement element;
  final double hpRatio;
}

class Death extends StageEvent {
  const Death({required this.actorId, this.captured = false});
  final String actorId;
  final bool captured;
}

class Shake extends StageEvent {
  const Shake({required this.amp});
  final double amp;
}
```

- [ ] **Step 4: 차분 구현**

`flutter/lib/ui/stage/state_diff.dart`:

```dart
import '../../domain/balance_config.dart';
import '../../domain/game_state.dart';
import '../../domain/monster.dart';
import 'stage_event.dart';

/// 몬스터 → 시트 id. 지역 안 순번을 기본 형태 4개에 돌려 붙인다. 나머지 변종은 [monsterHue]로.
String monsterSheetId(Monster m, MonsterCatalog catalog) => '${m.region}_${_indexInRegion(m, catalog) % 4 + 1}';

double monsterHue(Monster m, MonsterCatalog catalog) => (_indexInRegion(m, catalog) ~/ 4) * 90.0;

int _indexInRegion(Monster m, MonsterCatalog catalog) => catalog.monstersIn(m.region).indexWhere((x) => x.id == m.id).clamp(0, 1 << 20);

/// 이전 상태와 다음 상태의 차이를 무대 이벤트로 바꾼다. 기존 `BattleStageGame.sync` 의 규칙 그대로.
///
/// 지금 엔진은 1대1이라 몬스터 액터는 `mon1` 하나(보스는 `boss`). 다중 타깃은 이 함수만 바꾼다.
List<StageEvent> diffStageEvents(GameState? prev, GameState next, {required BalanceConfig config, required MonsterCatalog catalog}) {
  final out = <StageEvent>[];
  final m = catalog.byId(next.monsterId);
  final actorId = next.isBoss ? 'boss' : 'mon1';

  Spawn spawn() => Spawn(
        actorId: actorId,
        monsterId: next.monsterId,
        element: m?.element ?? MonsterElement.neutral,
        isBoss: next.isBoss,
        pixelSize: next.isBoss ? 96 : 48,
        hue: m == null ? 0 : monsterHue(m, catalog),
      );

  if (prev == null || catalog.regionFor(prev.stage)?.id != catalog.regionFor(next.stage)?.id || prev.stage != next.stage) {
    out.add(StageChanged(stage: next.stage, regionId: catalog.regionFor(next.stage)?.id));
  }
  if (prev == null) return out..add(spawn());

  final spawned = next.totalKills > prev.totalKills || next.monsterId != prev.monsterId || next.isBoss != prev.isBoss;
  final damage = prev.monsterHp - next.monsterHp;
  final dealt = spawned && next.totalKills > prev.totalKills ? prev.monsterHp : damage;
  if (dealt > 0) {
    final prevActor = prev.isBoss ? 'boss' : 'mon1';
    out.add(const Attack(actorId: 'hero'));
    out.add(Hit(
      targetId: prevActor,
      damage: dealt,
      crit: dealt > prev.statsWith(config).attack * 1.5,
      element: catalog.byId(prev.monsterId)?.element ?? MonsterElement.neutral,
      hpRatio: spawned ? 0 : (next.monsterHp / next.monsterMaxHp).clamp(0, 1),
    ));
  }
  if (spawned) {
    if (next.totalKills > prev.totalKills) out.add(Death(actorId: prev.isBoss ? 'boss' : 'mon1'));
    out.add(spawn());
    if (next.isBoss && !prev.isBoss) out.add(const Shake(amp: 8));
  }
  return out;
}
```

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/ui/stage/state_diff_test.dart` → 6 tests passed.

- [ ] **Step 6: 커밋**

```bash
git add lib/ui/stage/stage_event.dart lib/ui/stage/state_diff.dart test/ui/stage/state_diff_test.dart
git commit -m "feat(flutter): 무대 이벤트 타입 + GameState 차분 → 이벤트 (도메인·무대 단방향)"
```

---

### Task 12: 배경 2레이어

**Files:**
- Create: `flutter/lib/ui/stage/background_layers.dart`
- Test: `flutter/test/ui/stage/background_layers_test.dart`

**Interfaces:**
- Consumes: `regionColors` (`lib/ui/sprites/monster_sprite.dart`, 기존).
- Produces: `class BackgroundLayers extends PositionComponent { Future<void> setRegion(String? regionId); void slide(); double get farOffset; }` — 지역 배경이 있으면 `far.png`(y 0)·`ground.png`(y 110)를, 없으면 그라데이션을 그린다. `slide()`는 far 레이어를 0.5초 동안 24px 왼쪽으로 밀고(모듈로 360) 스테이지 전환마다 부른다.

- [ ] **Step 1: 테스트**

`flutter/test/ui/stage/background_layers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/stage/background_layers.dart';

void main() {
  test('slide는 0.5초에 걸쳐 24px 밀고 360에서 감긴다', () {
    final bg = BackgroundLayers();
    expect(bg.farOffset, 0);
    bg.slide();
    bg.update(0.25);
    expect(bg.farOffset, closeTo(12, 0.5));
    bg.update(0.25);
    expect(bg.farOffset, closeTo(24, 0.5));
    for (var i = 0; i < 15; i++) {
      bg.slide();
      bg.update(0.5);
    }
    expect(bg.farOffset, inInclusiveRange(0, 360));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/ui/stage/background_layers_test.dart` → 컴파일 실패.

- [ ] **Step 3: 구현**

`flutter/lib/ui/stage/background_layers.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../sprites/monster_sprite.dart' show regionColors;
import 'formation.dart';

/// 배경 원경(far, 0~110) + 지면(ground, 110~270). 에셋이 없으면 지역 그라데이션.
class BackgroundLayers extends PositionComponent {
  BackgroundLayers({Images? images}) : _images = images ?? Images(prefix: 'assets/backgrounds/');

  static const horizon = 110.0;
  static const _slidePx = 24.0, _slideTime = 0.5;

  final Images _images;
  final _pixel = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  String? _region;
  ui.Image? _far, _ground;
  double _offset = 0, _slideLeft = 0;

  double get farOffset => _offset;

  Future<void> setRegion(String? regionId) async {
    if (regionId == _region) return;
    _region = regionId;
    _far = null;
    _ground = null;
    if (regionId == null) return;
    try {
      _far = await _images.load('$regionId/far.png');
      _ground = await _images.load('$regionId/ground.png');
    } on Object {
      // 아직 없는 지역 — 그라데이션으로 둔다.
    }
  }

  void slide() => _slideLeft = _slideTime;

  @override
  void update(double dt) {
    super.update(dt);
    if (_slideLeft <= 0) return;
    final step = dt.clamp(0, _slideLeft);
    _slideLeft -= step;
    _offset = (_offset + _slidePx * step / _slideTime) % stageWidth;
  }

  @override
  void render(Canvas canvas) {
    final far = _far, ground = _ground;
    if (far == null || ground == null) {
      final rect = Rect.fromLTWH(0, 0, stageWidth, stageHeight);
      canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, regionColors(_region)));
      canvas.drawRect(Rect.fromLTWH(0, horizon, stageWidth, stageHeight - horizon), Paint()..color = Colors.black.withValues(alpha: 0.18));
      return;
    }
    final x = -_offset.roundToDouble();
    canvas.drawImage(far, Offset(x, 0), _pixel);
    canvas.drawImage(far, Offset(x + stageWidth, 0), _pixel); // 감김
    canvas.drawImage(ground, const Offset(0, horizon), _pixel);
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/ui/stage/background_layers_test.dart` → 1 test passed.

- [ ] **Step 5: 커밋**

```bash
git add lib/ui/stage/background_layers.dart test/ui/stage/background_layers_test.dart
git commit -m "feat(flutter): 배경 원경·지면 2레이어 + 스테이지 전환 슬라이드"
```

---

### Task 13: 무대 재작성 (카메라·레이어·이벤트·VFX·히트스톱)

**Files:**
- Modify: `flutter/lib/ui/stage/battle_stage_game.dart` (전면 재작성. `FloatingDamage`는 유지)
- Modify: `flutter/lib/ui/battle_area.dart` (`sync` → 차분 + `handle`)
- Test: `flutter/test/ui/stage/battle_stage_game_test.dart`, `flutter/test/ui/art_gallery_test.dart` 갱신

**Interfaces:**
- Consumes: Task 7~12 전부. `FloatingDamage`(기존).
- Produces: `class BattleStageGame extends FlameGame { BattleStageGame({required MonsterCatalog catalog, SheetLoader? loader, Images? bgImages}); MonsterCatalog catalog; Future<void> handle(StageEvent e); Actor? actorById(String id); double get hitStopLeft; Vector2 get shakeOffset; }`
- `handle`은 `Future`지만 `battle_area`는 기다리지 않고 순서대로 호출한다(내부 큐 직렬화).

- [ ] **Step 1: 테스트**

`flutter/test/ui/stage/battle_stage_game_test.dart`:

```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/monster.dart';
import 'package:idle_fantasy/ui/stage/actor_state.dart';
import 'package:idle_fantasy/ui/stage/battle_stage_game.dart';
import 'package:idle_fantasy/ui/stage/formation.dart';
import 'package:idle_fantasy/ui/stage/sheet_loader.dart';
import 'package:idle_fantasy/ui/stage/stage_event.dart';

import '../../support/catalog.dart';

/// 에셋 없이 도는 로더 — 전부 대체 실루엣.
class _NoAssetLoader extends SheetLoader {
  @override
  Future<LoadedSheet> load(String group, String id, {List<String> required = const ['idle', 'walk', 'attack', 'hit', 'death']}) =>
      throw StateError('no assets');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BattleStageGame> boot() async {
    final g = BattleStageGame(catalog: smallCatalog, loader: _NoAssetLoader());
    g.onGameResize(Vector2(360, 270));
    await g.onLoad();
    g.onMount();
    g.update(0);
    return g;
  }

  test('onLoad 후 주인공·펫이 슬롯에 서 있다', () async {
    final g = await boot();
    expect(g.actorById('hero')!.pos, allySlots['hero']);
    expect(g.actorById('pet')!.pos, allySlots['pet']);
  });

  test('Spawn은 몬스터 액터를 만들고 서쪽을 본다', () async {
    final g = await boot();
    await g.handle(const Spawn(actorId: 'mon1', monsterId: 1, element: MonsterElement.neutral, isBoss: false, pixelSize: 48, hue: 0));
    g.update(0);
    final m = g.actorById('mon1')!;
    expect(m.scale.x, -1);
    expect(m.pos, enemySlots(1).first);
    expect(m.showHpBar, isTrue);
  });

  test('Hit은 피격 모션·백플래시·히트스톱·데미지 숫자', () async {
    final g = await boot();
    await g.handle(const Spawn(actorId: 'mon1', monsterId: 1, element: MonsterElement.neutral, isBoss: false, pixelSize: 48, hue: 0));
    await g.handle(const Hit(targetId: 'mon1', damage: 40, crit: true, element: MonsterElement.fire, hpRatio: 0.6));
    g.update(0);
    final m = g.actorById('mon1')!;
    expect(m.state, ActorState.hit);
    expect(m.flashing, isTrue);
    expect(m.hpRatio, 0.6);
    expect(g.hitStopLeft, greaterThan(0));
    expect(g.descendants().whereType<FloatingDamage>().length, 1);
  });

  test('Death 후 액터는 death 상태로 남고 다음 Spawn이 같은 id를 교체한다', () async {
    final g = await boot();
    await g.handle(const Spawn(actorId: 'mon1', monsterId: 1, element: MonsterElement.neutral, isBoss: false, pixelSize: 48, hue: 0));
    await g.handle(const Death(actorId: 'mon1'));
    expect(g.actorById('mon1')!.state, ActorState.death);
    await g.handle(const Spawn(actorId: 'mon1', monsterId: 2, element: MonsterElement.wind, isBoss: false, pixelSize: 48, hue: 0));
    g.update(0);
    expect(g.actorById('mon1')!.state, ActorState.idle);
  });

  test('Shake는 루트를 흔들고 0.45초 뒤 제자리', () async {
    final g = await boot();
    await g.handle(const Shake(amp: 8));
    g.update(0.05);
    expect(g.shakeOffset, isNot(Vector2.zero()));
    g.update(0.5);
    expect(g.shakeOffset, Vector2.zero());
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/ui/stage/battle_stage_game_test.dart` → 컴파일 실패 (`handle`·`actorById` 없음).

- [ ] **Step 3: 무대 재작성**

`flutter/lib/ui/stage/battle_stage_game.dart` 전체를 다음으로 교체한다.

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../../domain/monster.dart';
import '../../domain/number_format.dart';
import '../sprites/monster_sprite.dart' show elementColor;
import 'actor.dart';
import 'actor_state.dart';
import 'background_layers.dart';
import 'formation.dart';
import 'sheet_loader.dart';
import 'sheet_spec.dart';
import 'stage_event.dart';
import 'state_diff.dart';

/// 전투 무대 — 가상 360×270 Flame 월드.
///
/// 게임 로직은 없다. 화면 계층이 [handle]로 이벤트를 밀어 넣으면 연출만 한다.
/// 레이어: 배경 → 액터(y 정렬, 히트스톱 대상) → 이펙트 → 데미지 숫자. 전부 흔들림 루트 아래.
class BattleStageGame extends FlameGame {
  BattleStageGame({required this.catalog, SheetLoader? loader, Images? bgImages})
      : _loader = loader ?? SheetLoader(),
        _bg = BackgroundLayers(images: bgImages);

  MonsterCatalog catalog;

  final SheetLoader _loader;
  final BackgroundLayers _bg;
  final _world = World();
  final _root = _ShakeRoot();
  final _actors = _ActorLayer();
  final _fx = PositionComponent();
  final _byId = <String, Actor>{};
  final _rng = math.Random();
  double _hitStop = 0;
  Future<void> _queue = Future.value();

  double get hitStopLeft => _hitStop;
  Vector2 get shakeOffset => _root.position;
  Actor? actorById(String id) => _byId[id];

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    await addAll([_world, CameraComponent.withFixedResolution(width: stageWidth, height: stageHeight, world: _world)]);
    await _world.add(_root);
    await _root.addAll([_bg, _actors, _fx]);
    await _spawnAlly('hero', 'hero', 'warrior_1', 48, Colors.blue);
    await _spawnAlly('pet', 'pet', 'fire_baby', 32, Colors.deepOrange);
  }

  Future<void> _spawnAlly(String actorId, String group, String sheetId, int size, Color fallback) async {
    final sheet = await _loader.loadOrFallback(group, sheetId, size: size, color: fallback);
    final a = Actor(id: actorId, sheet: sheet, pixelSize: size, facingRight: true)..pos.setFrom(allySlots[actorId]!);
    _byId[actorId] = a;
    await _actors.add(a);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitStop > 0) {
      _hitStop -= dt;
      if (_hitStop <= 0) _actors.timeScale = 1;
    }
    for (final c in _root.children.whereType<FloatingDamage>().toList()) {
      if (c.expired) _root.remove(c);
    }
    for (final c in _fx.children.whereType<_Burst>().toList()) {
      if (c.expired) _fx.remove(c);
    }
  }

  /// 이벤트는 들어온 순서대로 처리한다(Spawn의 시트 로드가 비동기라 큐로 직렬화).
  Future<void> handle(StageEvent e) => _queue = _queue.then((_) => _apply(e));

  Future<void> _apply(StageEvent e) async {
    switch (e) {
      case StageChanged(:final regionId):
        await _bg.setRegion(regionId);
        _bg.slide();
      case Spawn():
        await _spawnEnemy(e);
      case Attack(:final actorId):
        _byId[actorId]?.play(ActorState.attack);
      case Hit():
        _hit(e);
      case Death(:final actorId):
        final a = _byId[actorId];
        if (a != null) {
          a.play(ActorState.death);
          _burst(a.pos, elementColor(_elementOf(actorId)));
        }
      case Shake(:final amp):
        _root.shake(amp);
    }
  }

  final _elements = <String, MonsterElement>{};
  MonsterElement _elementOf(String actorId) => _elements[actorId] ?? MonsterElement.neutral;

  Future<void> _spawnEnemy(Spawn e) async {
    final old = _byId.remove(e.actorId);
    if (old != null) _actors.remove(old);
    final m = catalog.byId(e.monsterId);
    final group = e.isBoss ? 'boss' : 'monster';
    final sheetId = e.isBoss ? (m?.region ?? 'forest') : (m == null ? 'forest_1' : monsterSheetId(m, catalog));
    final sheet = await _loader.loadOrFallback(group, sheetId, size: e.pixelSize, color: elementColor(e.element));
    final slot = e.isBoss ? bossSlot : enemySlots(1).first; // 다중 타깃은 서브프로젝트 3에서 슬롯 배분
    final a = Actor(id: e.actorId, sheet: sheet, pixelSize: e.pixelSize, facingRight: false, hue: e.hue)
      ..pos.setFrom(slot)
      ..showHpBar = true;
    _elements[e.actorId] = e.element;
    _byId[e.actorId] = a;
    await _actors.add(a);
    a.play(ActorState.walk);
    a.play(ActorState.idle);
  }

  void _hit(Hit e) {
    final a = _byId[e.targetId];
    if (a == null) return;
    a.play(ActorState.hit);
    a.flash();
    a.hpRatio = e.hpRatio;
    _hitStop = e.crit ? 0.08 : 0.05;
    _actors.timeScale = 0;
    if (e.crit) _root.shake(3);
    final floaters = _root.children.whereType<FloatingDamage>().toList();
    if (floaters.length >= 6) _root.remove(floaters.first);
    _root.add(FloatingDamage(
      text: formatNumber(e.damage),
      crit: e.crit,
      start: a.pos + Vector2(_rng.nextDouble() * 24 - 12, -a.pixelSize * 0.9 - _rng.nextDouble() * 10),
    ));
    _spark(a.pos + Vector2(0, -a.pixelSize / 2), elementColor(e.element));
  }

  void _spark(Vector2 at, Color color) => _fx.add(_Burst(position: at, particle: _particles(count: 8, lifespan: 0.35, color: color, speed: 70)));
  void _burst(Vector2 at, Color color) => _fx.add(_Burst(position: at, particle: _particles(count: 14, lifespan: 0.6, color: color, speed: 110)));

  Particle _particles({required int count, required double lifespan, required Color color, required double speed}) => Particle.generate(
        count: count,
        lifespan: lifespan,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * (speed * (0.6 + _rng.nextDouble() * 0.8)),
            acceleration: Vector2(0, 220),
            child: CircleParticle(radius: 1 + _rng.nextDouble() * 1.5, paint: Paint()..color = color),
          );
        },
      );
}

/// 히트스톱 대상 — 이 레이어의 시간만 멈춘다.
class _ActorLayer extends PositionComponent with HasTimeScale {}

/// 모든 레이어의 부모. 흔들림은 이 컴포넌트의 position을 흔든다.
class _ShakeRoot extends PositionComponent {
  double _left = 0, _amp = 0;
  static const _time = 0.45;

  void shake(double amp) {
    _left = _time;
    _amp = amp;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_left <= 0) {
      if (position != Vector2.zero()) position.setZero();
      return;
    }
    _left -= dt;
    if (_left <= 0) {
      position.setZero();
      return;
    }
    final t = 1 - _left / _time;
    position.setValues(math.sin(t * math.pi * 8) * (1 - t) * _amp, math.cos(t * math.pi * 6) * (1 - t) * _amp * 0.5);
  }
}

class _Burst extends ParticleSystemComponent {
  _Burst({super.position, super.particle});
  bool get expired => particle?.shouldRemove ?? true;
  @override
  void update(double dt) => particle?.update(dt);
}

/// 떠오르는 데미지 숫자. 픽셀 무대 기준이라 글자가 작다(무대가 확대되며 같이 커진다).
class FloatingDamage extends PositionComponent {
  FloatingDamage({required this.text, required this.crit, required Vector2 start}) : super(position: start.clone(), anchor: Anchor.center);

  final String text;
  final bool crit;
  double _life = 0;
  static const _span = 0.6;

  bool get expired => _life >= _span;

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    position.y -= dt * 40;
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _span).clamp(0.0, 1.0);
    final alpha = t < 0.7 ? 1.0 : (1 - t) / 0.3;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: (crit ? Colors.amber : Colors.white).withValues(alpha: alpha),
          fontSize: crit ? 13 : 9,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Colors.black.withValues(alpha: alpha * 0.8), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
  }
}
```

- [ ] **Step 4: battle_area 브리지**

`flutter/lib/ui/battle_area.dart` 에서:

```dart
// import 추가
import 'stage/state_diff.dart';
import '../domain/game_state.dart';

// 필드: config 생성자 인자 제거
late final BattleStageGame _game = BattleStageGame(catalog: ref.read(monsterCatalogProvider));
GameState? _lastSynced;

// build() 안의 listen 교체
ref.listen(gameControllerProvider, (_, next) {
  final events = diffStageEvents(_lastSynced, next, config: ref.read(balanceConfigProvider), catalog: ref.read(monsterCatalogProvider));
  _lastSynced = next;
  for (final e in events) {
    _game.handle(e);
  }
});

// _game..catalog = catalog ..config = config  →  _game.catalog = catalog;
```

`GameWidget`을 감싸는 `Positioned.fill`은 그대로 둔다(부모가 4:3 `AspectRatio`를 준다 — Task 14). 초기 상태는 `initState`에서 한 번 밀어 넣는다:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final s = ref.read(gameControllerProvider);
    for (final e in diffStageEvents(null, s, config: ref.read(balanceConfigProvider), catalog: ref.read(monsterCatalogProvider))) {
      _game.handle(e);
    }
    _lastSynced = s;
  });
}
```

- [ ] **Step 5: 갤러리 테스트 갱신**

`flutter/test/ui/art_gallery_test.dart` 의 두 번째 테스트(`전투 무대(Flame)를 PNG로 내보낸다`)를 다음으로 교체하고, 첫 번째 테스트는 Task 15에서 손보므로 그대로 둔다.

```dart
  test('전투 무대(Flame)를 PNG로 내보낸다 — 시트 없으면 실루엣', () async {
    final game = BattleStageGame(catalog: loadBundledCatalog());
    game.onGameResize(Vector2(360, 270));
    await game.onLoad();
    game.onMount();
    game.update(0);
    await game.handle(const StageChanged(stage: 130, regionId: 'volcano'));
    await game.handle(const Spawn(actorId: 'boss', monsterId: 30, element: MonsterElement.fire, isBoss: true, pixelSize: 96, hue: 0));
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
    }
    await game.handle(const Hit(targetId: 'boss', damage: 1200, crit: true, element: MonsterElement.fire, hpRatio: 0.9));
    for (var i = 0; i < 8; i++) {
      game.update(1 / 60);
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(3);
    game.render(canvas);
    final image = await recorder.endRecording().toImage(1080, 810);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/battle_stage.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(file.lengthSync(), greaterThan(10000));
  });
```

import에 `package:idle_fantasy/domain/monster.dart`, `package:idle_fantasy/ui/stage/stage_event.dart` 를 추가하고 `GameState`·`BalanceConfig` import 중 안 쓰게 된 것은 지운다.

- [ ] **Step 6: 통과 확인**

Run: `flutter test test/ui/stage/ test/ui/art_gallery_test.dart`
Expected: 전부 passed. `build/battle_stage.png` 를 열어 실루엣 보스와 데미지 숫자가 보이는지 확인.

- [ ] **Step 7: 커밋**

```bash
git add lib/ui/stage/battle_stage_game.dart lib/ui/battle_area.dart test/ui
git commit -m "feat(flutter): 무대 재작성 — 360×270 고정 뷰포트, 레이어·y정렬·히트스톱·이벤트 브리지"
```

---

### Task 14: 화면 레이아웃 (무대 4:3 + 스킬 바 + 탭)

**Files:**
- Create: `flutter/lib/ui/skill_bar.dart`
- Create: `flutter/lib/ui/tabs/upgrade_tab.dart`, `party_tab.dart`, `equipment_tab.dart`, `codex_tab.dart`
- Modify: `flutter/lib/ui/game_screen.dart`, `flutter/lib/ui/codex_screen.dart`
- Test: `flutter/test/ui/game_screen_test.dart`

**Interfaces:**
- Produces: `SkillBar` (버튼 4개, `onTap` 없음·비활성), `UpgradeTab`, `PartyTab`, `EquipmentTab`, `CodexTab`(기존 `CodexScreen` 본문). `GameScreen`은 `NavigationBar` 4개 목적지.

- [ ] **Step 1: 위젯 테스트**

`flutter/test/ui/game_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/app/game_controller.dart';
import 'package:idle_fantasy/ui/game_screen.dart';
import 'package:idle_fantasy/ui/skill_bar.dart';
import 'package:idle_fantasy/ui/tabs/codex_tab.dart';
import 'package:idle_fantasy/ui/tabs/equipment_tab.dart';
import 'package:idle_fantasy/ui/tabs/party_tab.dart';
import 'package:idle_fantasy/ui/tabs/upgrade_tab.dart';

import '../support/catalog.dart';
import '../support/in_memory_save_repository.dart';

void main() {
  Widget app() => ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          monsterCatalogProvider.overrideWithValue(smallCatalog),
        ],
        child: const MaterialApp(home: GameScreen()),
      );

  testWidgets('무대는 4:3, 스킬 바 4칸, 기본 탭은 강화', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pump();

    final stage = tester.getSize(find.byKey(const Key('stage')));
    expect(stage.width / stage.height, closeTo(4 / 3, 0.01));
    expect(find.byType(SkillBar), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsNWidgets(4));
    expect(find.byType(UpgradeTab), findsOneWidget);
    expect(find.text('공격력  Lv.0'), findsOneWidget);
  });

  testWidgets('탭을 누르면 내용이 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('편성'));
    await tester.pump();
    expect(find.byType(PartyTab), findsOneWidget);
    await tester.tap(find.text('장비'));
    await tester.pump();
    expect(find.byType(EquipmentTab), findsOneWidget);
    await tester.tap(find.text('도감'));
    await tester.pump();
    expect(find.byType(CodexTab), findsOneWidget);
  });

  testWidgets('작은 기기(375×667)에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/ui/game_screen_test.dart` → 컴파일 실패.

- [ ] **Step 3: 스킬 바**

`flutter/lib/ui/skill_bar.dart`:

```dart
import 'package:flutter/material.dart';

/// 스킬 바 자리 — 직업 스킬 3 + 펫 스킬 1. 스킬 시스템(서브프로젝트 2)이 오면 버튼에 쿨타임·탭 발동을 붙인다.
class SkillBar extends StatelessWidget {
  const SkillBar({super.key});

  static const height = 60.0;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: outline, width: 1.5)),
                child: Icon(Icons.bolt, size: 18, color: outline),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 탭 위젯**

`flutter/lib/ui/tabs/upgrade_tab.dart` — `game_screen.dart`의 `ListView`(골드·DPS·업그레이드 5종·저장 상태)와 `_UpgradeRow`, `_saveLine`을 그대로 옮긴다:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../domain/number_format.dart';
import '../../domain/upgrade.dart';

/// 강화 탭 — 골드·DPS 요약 + 능력치 5종 업그레이드 + 저장 상태.
class UpgradeTab extends ConsumerWidget {
  const UpgradeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final saveStatus = ref.watch(saveStatusProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final stats = state.statsWith(config);
    final mono = Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');
    final pending = state.killLog.values.fold(0, (a, b) => a + b) + state.bossKillLog.values.fold(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('골드  ${formatNumber(state.gold)}', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            Text('DPS ${formatNumber(stats.dps(config))}', style: mono),
          ],
        ),
        Text(
          '공격 ${formatNumber(stats.attack)}  속도 ${stats.attacksPerSecond.toStringAsFixed(1)}/s  '
          '치명 ${(stats.critChance * 100).toStringAsFixed(0)}%  골드 ×${stats.goldMultiplier.toStringAsFixed(2)}',
          style: mono?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 8),
        for (final type in UpgradeType.values)
          _UpgradeRow(
            type: type,
            level: state.levelOf(type),
            cost: type.cost(state.levelOf(type), config),
            affordable: state.gold >= type.cost(state.levelOf(type), config),
            onBuy: () => controller.buyUpgrade(type),
          ),
        const SizedBox(height: 16),
        Text('총 처치 ${state.totalKills}  ·  미보고 처치 $pending', style: mono),
        Text(_saveLine(context, saveStatus), style: mono?.copyWith(color: Theme.of(context).colorScheme.outline)),
        if (saveStatus.lastRejectedRule != null)
          Text('서버 검증 거부(${saveStatus.lastRejectedRule}) — 서버 상태로 되돌렸습니다', style: mono?.copyWith(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}

String _saveLine(BuildContext context, SaveStatus s) {
  String hms(DateTime t) => '${TimeOfDay.fromDateTime(t).format(context)}:${t.second.toString().padLeft(2, '0')}';
  final saved = s.lastSavedAt == null ? '저장 전' : '로컬 저장 ${hms(s.lastSavedAt!)}';
  final synced = s.lastSyncedAt == null ? '서버 미동기화' : '서버 동기화 ${hms(s.lastSyncedAt!)}';
  return '$saved · $synced';
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({required this.type, required this.level, required this.cost, required this.affordable, required this.onBuy});

  final UpgradeType type;
  final int level;
  final double cost;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text('${type.label}  Lv.$level')),
          FilledButton(onPressed: affordable ? onBuy : null, child: Text('${formatNumber(cost)} G')),
        ],
      ),
    );
  }
}
```

`flutter/lib/ui/tabs/party_tab.dart`:

```dart
import 'package:flutter/material.dart';

import '../party_row.dart';

/// 편성 탭 — 동료 3칸(기존 PartyRow) + 펫 1칸(알·펫 서브프로젝트에서 채운다).
class PartyTab extends StatelessWidget {
  const PartyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return ListView(
      children: [
        const PartyRow(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('펫', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(border: Border.all(color: outline, width: 1.5), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.egg_outlined, size: 18, color: outline),
              ),
              const Spacer(),
              Text('알은 곧 열립니다', style: TextStyle(color: outline, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
```

`flutter/lib/ui/tabs/equipment_tab.dart`:

```dart
import 'package:flutter/material.dart';

/// 장비 탭 자리 — 아이템·장비 서브프로젝트에서 채운다.
class EquipmentTab extends StatelessWidget {
  const EquipmentTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('장비는 곧 열립니다', style: TextStyle(color: Theme.of(context).colorScheme.outline)));
  }
}
```

`flutter/lib/ui/tabs/codex_tab.dart` — `CodexScreen`의 `Scaffold.body`(`ListView`)를 그대로 옮긴다. `codex_screen.dart`는 `CodexScreen`이 `Scaffold(appBar, body: const CodexTab())`만 남기도록 줄이고 `_RegionHeader` 등 보조 위젯은 `codex_tab.dart`로 이동한다:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../domain/codex.dart';
import '../../domain/monster.dart';
import '../sprites/monster_sprite.dart';

/// 도감 탭 — 지역별 스프라이트 그리드. (기존 CodexScreen 본문)
class CodexTab extends ConsumerWidget {
  const CodexTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 기존 CodexScreen.build 의 `body:` 이하 ListView를 그대로 반환한다. 등록 수 헤더는 첫 항목으로 넣는다.
    // (코드는 codex_screen.dart 에서 잘라 붙인다 — 내용 변경 없음)
    throw UnimplementedError('codex_screen.dart 의 body 를 옮긴다');
  }
}
```

위 `throw`는 옮기는 동안의 자리이며, 옮기고 나면 남지 않아야 한다. `flutter analyze`에 `UnimplementedError`가 검색되지 않는지 확인한다: `grep -rn UnimplementedError lib/ui/tabs` → 결과 없음.

- [ ] **Step 5: 게임 화면 골격**

`flutter/lib/ui/game_screen.dart` 의 `build`를 다음으로 교체하고, 옮겨 간 `_UpgradeRow`·`_saveLine`·불필요 import를 지운다.

```dart
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final registered = state.codex.values.where((s) => s > 0).length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text('스테이지 ${state.stage}  (최고 ${state.highestStage})'),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text('골드 ${formatNumber(state.gold)}')))],
      ),
      body: Column(
        children: [
          const AspectRatio(key: Key('stage'), aspectRatio: 4 / 3, child: BattleArea()),
          const SkillBar(),
          const Divider(height: 1),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [UpgradeTab(), PartyTab(), EquipmentTab(), CodexTab()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 48,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.trending_up), label: '강화'),
          const NavigationDestination(icon: Icon(Icons.groups), label: '편성'),
          const NavigationDestination(icon: Icon(Icons.shield_outlined), label: '장비'),
          NavigationDestination(icon: const Icon(Icons.menu_book), label: '도감 $registered'),
        ],
      ),
    );
  }
```

`_showOfflineReward`와 `initState`는 그대로 둔다. import에 `skill_bar.dart`, `tabs/*.dart` 를 추가하고 `codex_screen.dart`, `party_row.dart`, `upgrade.dart`, `offline_reward.dart`(여전히 사용) 중 안 쓰는 것을 정리한다.

- [ ] **Step 6: 통과 확인**

Run: `flutter test test/ui/game_screen_test.dart && flutter analyze`
Expected: 3 tests passed, analyze 경고 0. 도감 탭 라벨은 `'도감 0'`이므로 두 번째 테스트의 `find.text('도감')`이 못 찾으면 `find.textContaining('도감')`으로 바꾼다.

- [ ] **Step 7: 실기기 확인**

`flutter run` 으로 375pt 기기에서: 무대가 4:3으로 위에 고정, 스킬 바 4칸, 탭 4개 전환, 667pt 기기(또는 시뮬레이터 iPhone SE)에서 강화 탭이 스크롤되는지 확인.

- [ ] **Step 8: 커밋**

```bash
git add lib/ui test/ui/game_screen_test.dart
git commit -m "feat(flutter): 화면 레이아웃 — 무대 4:3 고정 + 스킬 바 + 강화·편성·장비·도감 탭"
```

---

### Task 15: 벡터 페인터 제거와 에셋 등록

**Files:**
- Modify: `flutter/lib/ui/sprites/monster_sprite.dart` (시트 첫 프레임 기반으로 교체, `elementColor`·`regionColors` 유지)
- Delete: `flutter/lib/ui/sprites/hero_painter.dart`, `flutter/lib/ui/sprites/dragon_painter.dart`
- Delete: `flutter/lib/spike/`, `flutter/lib/spike_main.dart`
- Modify: `flutter/pubspec.yaml` (모든 에셋 폴더), `flutter/test/ui/art_gallery_test.dart` (첫 테스트 교체)
- Test: `flutter/test/ui/monster_sprite_test.dart`

**Interfaces:**
- Produces: `class MonsterSprite extends StatelessWidget { MonsterSprite({required Monster? monster, required MonsterCatalog catalog, double size = 48, bool isBoss = false, bool silhouette = false}) }` — 시트의 idle 첫 프레임을 그린다. 시트가 없으면 속성색 실루엣. `silhouette=true`면 검은 실루엣.

- [ ] **Step 1: 테스트**

`flutter/test/ui/monster_sprite_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/ui/sprites/monster_sprite.dart';

import '../support/catalog.dart';

void main() {
  testWidgets('시트가 없어도 실루엣을 그리고 예외가 없다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MonsterSprite(monster: smallCatalog.byId(1), catalog: smallCatalog, size: 48)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(MonsterSprite)), const Size(48, 48));
  });

  testWidgets('silhouette는 검은 실루엣', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MonsterSprite(monster: smallCatalog.byId(1), catalog: smallCatalog, silhouette: true)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('silhouette')), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/ui/monster_sprite_test.dart` → 컴파일 실패 (`catalog` 인자 없음).

- [ ] **Step 3: MonsterSprite 교체**

`flutter/lib/ui/sprites/monster_sprite.dart` 에서 `MonsterPainter` 클래스와 `MonsterSprite` 를 지우고 다음으로 바꾼다. `elementColor`·`regionColors`는 그대로 둔다.

```dart
import 'package:flame/components.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

import '../../domain/monster.dart';
import '../stage/hue_filter.dart';
import '../stage/sheet_loader.dart';
import '../stage/state_diff.dart';

/// 도감·편성용 몬스터 정지 이미지 — 무대 시트의 idle 첫 프레임. 시트가 없으면 속성색 실루엣.
class MonsterSprite extends StatelessWidget {
  const MonsterSprite({super.key, required this.monster, required this.catalog, this.size = 48, this.isBoss = false, this.silhouette = false});

  static final _loader = SheetLoader();

  final Monster? monster;
  final MonsterCatalog catalog;
  final double size;
  final bool isBoss;
  final bool silhouette;

  @override
  Widget build(BuildContext context) {
    final m = monster;
    if (m == null || silhouette) {
      return Container(
        key: const Key('silhouette'),
        width: size,
        height: size,
        alignment: Alignment.bottomCenter,
        child: Container(width: size * 0.7, height: size * 0.9, decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(size * 0.25))),
      );
    }
    final px = isBoss ? 96 : 48;
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<LoadedSheet>(
        future: _loader.loadOrFallback(isBoss ? 'boss' : 'monster', isBoss ? m.region : monsterSheetId(m, catalog), size: px, color: elementColor(m.element)),
        builder: (context, snap) {
          final sheet = snap.data;
          if (sheet == null) return const SizedBox.shrink();
          final (start, _) = sheet.spec.animations['idle']!;
          final sprite = Sprite(sheet.image, srcPosition: Vector2(start * sheet.spec.frameWidth.toDouble(), 0), srcSize: Vector2(sheet.spec.frameWidth.toDouble(), sheet.spec.frameHeight.toDouble()));
          final hue = monsterHue(m, catalog);
          Widget w = SpriteWidget(sprite: sprite, paint: Paint()..filterQuality = FilterQuality.none..isAntiAlias = false);
          if (hue != 0) w = ColorFiltered(colorFilter: hueRotation(hue), child: w);
          // 몬스터는 왼쪽을 본다(동쪽 시트 반전).
          return Transform.flip(flipX: true, child: w);
        },
      ),
    );
  }
}
```

호출부(`codex_tab.dart`, `battle_area.dart` 등)에 `catalog:` 인자를 추가한다. `flutter analyze`로 누락을 찾는다.

- [ ] **Step 4: 페인터·스파이크 삭제, 에셋 등록**

```bash
git rm lib/ui/sprites/hero_painter.dart lib/ui/sprites/dragon_painter.dart
git rm -r lib/spike lib/spike_main.dart
```

`pubspec.yaml` `assets:`:

```yaml
  assets:
    - assets/monsters.json
    - assets/sprites/hero/
    - assets/sprites/pet/
    - assets/sprites/monster/
    - assets/sprites/boss/
    - assets/backgrounds/forest/
    - assets/vfx/
    - assets/icons/items/
```

`assets/icons/items/.gitkeep` 을 만든다(빈 폴더는 pubspec에서 오류).

- [ ] **Step 5: 갤러리 테스트 첫 항목 교체**

`test/ui/art_gallery_test.dart` 의 첫 `testWidgets`에서 `HeroPainter`·`DragonPainter` 줄을 지우고 `MonsterSprite(monster: catalog.byId(id), catalog: catalog, size: 100)` 로 바꾼다. 안 쓰는 import 제거.

- [ ] **Step 6: 전체 테스트·분석**

Run: `flutter analyze && flutter test`
Expected: 경고 0, 전부 passed.

- [ ] **Step 7: ART_GUIDE 3장 갱신**

`ART_GUIDE.md` 3장 "앱에 넣는 절차"를 다음 내용으로 바꾼다: 프레임을 `tools/frames/<id>/<anim>/`에 두고 `tools/sheet_pack.py`로 묶어 `assets/sprites/<group>/`에 넣는다. 몬스터 시트 id는 `<region>_<1~4>`이고 지역 내 순번으로 자동 매핑된다(`monsterSheetId`). 배경은 `tools/bg_pixelize.py`. 없는 에셋은 실루엣으로 대체되므로 지역 단위로 넣어 가며 확인한다.

- [ ] **Step 8: 커밋**

```bash
git add -A lib/ui/sprites pubspec.yaml assets/icons test/ui ../ART_GUIDE.md
git commit -m "refactor(flutter): 코드 벡터 페인터·스파이크 제거, 도감 스프라이트를 시트 기반으로, 에셋 폴더 등록"
```

---

### Task 16: 물량 생성 착수 (숲 지역 완성)

**Files:**
- Create: `flutter/assets/sprites/monster/forest_3.png` `.json`, `forest_4.png` `.json`
- Create: `flutter/assets/sprites/hero/archer_1.png` `ranger_1.png` … (직업·전직 스펙 확정 후 id 결정)
- Modify: `ART_GUIDE.md` (진행표)

이 태스크는 서브프로젝트 2·4의 결정을 받아 진행하며, 이 계획에서는 **숲 지역 몬스터 기본 형태 4개를 채우는 것**까지만 한다.

- [ ] **Step 1: forest_3, forest_4 생성**

Task 3 Step 2와 같은 절차로 `create_character` + `animate_character`. 설명:

| id | 설명 |
|---|---|
| monster/forest_3 | `small mushroom creature with a wide red cap, tiny legs, sleepy eyes` |
| monster/forest_4 | `young wolf pup, grey fur, pointy ears, alert eyes` |

```bash
V=tools/.venv/bin/python
$V tools/sheet_pack.py tools/frames/forest_3 assets/sprites/monster/forest_3 --size 48
$V tools/sheet_pack.py tools/frames/forest_4 assets/sprites/monster/forest_4 --size 48
```

- [ ] **Step 2: 앱에서 확인**

`flutter run` 후 도감 탭에서 숲 몬스터 10종이 형태 4개 × 색 변종으로 보이는지 확인. 실루엣(대체)이 남아 있으면 id 매핑(`monsterSheetId`)과 파일명을 대조한다.

- [ ] **Step 3: 진행표**

`ART_GUIDE.md`에 물량 진행표를 만든다:

| 그룹 | 완료 / 목표 |
|---|---|
| 주인공 | 2 / 8 |
| 펫 | 1 / 10 |
| 몬스터 기본 형태 | 4 / 20 |
| 보스 | 1 / 5 |
| 배경 | 1 / 5 |
| 아이템 아이콘 | 0 / 약 60 |

- [ ] **Step 4: 커밋**

```bash
git add assets/sprites/monster ../ART_GUIDE.md
git commit -m "art: 숲 지역 몬스터 기본 형태 4종 완성"
```

---

## Self-Review

**Spec coverage**
- 1장 규격(크기·방향·애니메이션 세트·파일 규격·JSON): Task 2(스크립트), 7(파싱·검증), Global Constraints. ✔
- 2장 도구 연결·생성 순서·합격 기준·분기: Task 1, 3, 4, 5, 6. ✔
- 3장 카메라·레이어·컴포넌트(로더·액터·진형·VFX·히트스톱·데미지 숫자)·이벤트·테스트: Task 7~13. VFX 시트 애니메이션 재생(스킬 이펙트)은 스킬이 없는 지금 파티클로만 두고, `SheetSpec.fromJson(required: ['play'])`로 VFX 시트 파싱 경로만 열어 둔다 — 스킬 서브프로젝트에서 재생 컴포넌트를 붙인다. 스펙 3장의 "VFX: 위치 지정 일회성 애니메이션"은 그때 구현한다고 명시.
- 4장 레이아웃(헤더·4:3 무대·스킬 바·탭·작은 기기): Task 14. ✔
- 5장 검증 순서·일정: Phase A/B 구조와 Task 6 게이트, 3단계는 Task 16. ✔
- 6장 제외 항목: 다중 타깃 슬롯 배분은 Task 13에 주석으로 위치만 표시. ✔

**Placeholder scan**: Task 14 Step 4의 `CodexTab` 본문은 기존 파일에서 잘라 붙이는 작업이라 코드를 재수록하지 않았고, 임시 `throw`가 남지 않도록 grep 확인 단계를 두었다. 그 외 TBD·"적절히"·"유사하게" 없음.

**Type consistency**: `LoadedSheet.animation(name, {required bool loop})` (Task 7) ↔ Task 9 사용 일치. `Actor(id:, sheet:, pixelSize:, facingRight:, hue:)` (Task 9) ↔ Task 13 일치. `enemySlots(int)`·`allySlots`·`bossSlot` (Task 10) ↔ Task 13 일치. `Spawn(actorId, monsterId, element, isBoss, pixelSize, hue)` (Task 11) ↔ Task 13 테스트 일치. `SheetLoader.loadOrFallback(group, id, {size, color})` ↔ Task 13·15 일치. `hitStopLeft`·`shakeOffset`·`actorById` ↔ 테스트 일치.
