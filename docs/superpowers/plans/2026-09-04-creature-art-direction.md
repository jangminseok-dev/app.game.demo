# 캐릭터·몬스터 화풍 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 캐릭터·몬스터 화풍을 "귀엽고 미니멀한 실루엣 + 뒤로 갈수록 용을 닮아 감"으로 확정하고, 문서를 그 규격으로 갈아 끼운 뒤, 실제로 4마리를 뽑아 눈으로 판정한다.

**Architecture:** 코드 변경은 없다. 세 가지다 — ① 문서 세 개(`ART_GUIDE.md` · `GAME_DESIGN.md` · `docs/BACKLOG.md`)를 새 규격으로 맞추고, ② 합격 기준을 기계로 검사할 작은 도구 하나를 `flutter/tools/`에 더하고, ③ PixelLab으로 4마리를 뽑아 사용자가 판정한다. 판정에서 떨어지면 스타일 블록이나 단계 표를 고치고 다시 뽑는다.

**Tech Stack:** Markdown 문서 / Python 3 + Pillow (`flutter/tools/` 기존 도구와 같은 방식) / PixelLab MCP

**Spec:** `docs/superpowers/specs/2026-09-04-creature-art-direction-design.md`

## Global Constraints

스펙에서 그대로 옮긴 값이다. 모든 태스크의 요구사항에 이것이 포함된다.

- **색 수**: 몬스터 1종당 **5색** — 몸통 / 밝은 면 / 그림자 / 특징색 / 눈·외곽선 공용
- **명암**: 2단만. 본체 + 그림자 1단. 그라데이션·질감 없음
- **외곽선**: 1px, 몸통색을 어둡게 한 색. **검정 금지**
- **내부 선**: 없음. 부위 구분은 색 면으로만
- **눈**: 흰자 + 검은 동공 + 1px 하이라이트. 유일한 디테일
- **등신**: 2~2.5등신. 머리가 몸과 같거나 크다
- **실루엣**: 둥근 덩어리 하나. **크게 그리는 특징은 그 지역에서 새로 더해진 것 하나만**, 8px 이상 튀어나오게. 물려받은 특징은 `small` · `faint`로 눌러 둔다
- **크기** (`2026-09-03-art-pipeline-design.md` §1에서 그대로 — 바꾸지 않는다): 주인공 56×56 · 일반 몬스터 48×48 · 보스 96×96 · 펫 32(새끼)/48(성체) · 아이콘 32×32 · 무대 가로 360픽셀
- **스타일 블록은 100종 내내 한 글자도 바꾸지 않는다.** 고칠 때는 한 줄씩만
- **IP 경계**: 화풍과 구조는 가져오되 레퍼런스의 등장인물 이름·고유명(우르스, 칠죄종 등)은 코드·UI·에셋 이름에 넣지 않는다
- 문체는 기존 문서를 따른다 — 평서형, 짧게, 존댓말 없음

## File Structure

| 파일 | 책임 | 처리 |
|---|---|---|
| `ART_GUIDE.md` | 생성기에 넣는 실제 규격과 프롬프트. **화풍의 정본** | §1·§2·§3 교체, §4에 결정 추가 |
| `GAME_DESIGN.md` 18장 | 세계관. 화풍이 세계관과 같은 말을 하는지의 근거 | 18.2 한 줄 뒤집기, 18.8 갱신 |
| `docs/BACKLOG.md` D절 | 아트 남은 일 | 화풍 확정 반영 |
| `flutter/tools/count_colors.py` | 색 수 검사. 합격 기준 2번을 기계로 판정 | 신규 |
| 스파이크 산출물 | 판정용. **출시 물량이 아니다** | scratchpad에 두고 버린다 |

**코드 변경 없음.** `stage_actor.dart:201` `hueRotation`이 휘도 보존 색상 회전이라 무채색을 그대로 둔다. 즉 "눈·외곽선을 팔레트 스왑에서 제외"는 눈·외곽선을 어둡고 채도 낮게 **그리는 것**으로 충족된다. 스펙 8절의 미결 항목이 이것이며, 아트 제약이지 코드 작업이 아니다.

---

### Task 1: ART_GUIDE.md를 새 규격으로 교체

**Files:**
- Modify: `ART_GUIDE.md` (전체 70줄 → 새 내용)

**Interfaces:**
- Consumes: 스펙 2·3·4절
- Produces: 이후 모든 생성이 참조하는 스타일 블록·용 단계 표·캐릭터 블록 형식

지금 이 문서는 2026-09-03의 옛 결정(2D 카툰, 512×512, 벡터풍)이 그대로 남아 `2026-09-03-art-pipeline-design.md`의 픽셀 규격과 어긋나 있다. §3도 사실과 다르다 — 에셋 경로를 `flutter/assets/monsters/`라 적었으나 실제는 `flutter/assets/sprites/monster/`이고, "PNG 로더는 아직 없다"고 적혀 있으나 `flutter/lib/ui/stage/sheet_loader.dart`가 이미 붙어 동작한다.

- [ ] **Step 1: 지금 어긋난 것을 눈으로 확인한다**

```bash
grep -n "512×512\|카툰\|assets/monsters/\|지금은 벡터만" ART_GUIDE.md
ls flutter/assets/sprites/monster/
```

기대: `ART_GUIDE.md`에서 네 패턴이 다 잡히고, 실제 스프라이트는 `flutter/assets/sprites/monster/forest_1.png` 등에 있다. 이 두 결과의 불일치가 이 태스크가 존재하는 이유다.

- [ ] **Step 2: ART_GUIDE.md를 통째로 다시 쓴다**

```bash
cat > ART_GUIDE.md <<'EOF'
# 아트 가이드 — 화풍 규격과 생성 프롬프트

목표 화풍: **귀엽고 미니멀한 픽셀아트.** 남녀노소가 보는 그림이다.
실루엣 언어는 팰월드(둥근 덩어리 + 특징 하나), 크리처 계통은 드래곤빌리지3(용)를 참고한다.

이 문서는 **"한 칸 안에 무엇을 넣는가"의 정본**이다.
크기·애니메이션·도구·파이프라인은 `docs/superpowers/specs/2026-09-03-art-pipeline-design.md`가,
왜 이 화풍인가는 `docs/superpowers/specs/2026-09-04-creature-art-direction-design.md`가 정한다.

## 1. 규격

크기는 `2026-09-03-art-pipeline-design.md` §1을 따른다.
주인공 56×56 · 일반 몬스터 48×48 · 보스 96×96 · 펫 32(새끼)/48(성체) · 아이콘 32×32 · 무대 가로 360픽셀.

한 칸 안의 내용은 이렇다.

| 항목 | 값 | 이유 |
|---|---|---|
| 색 수 | **1종당 5색** — 몸통 / 밝은 면 / 그림자 / 특징색 / 눈·외곽선 공용 | 색이 늘면 미니멀이 아니라 "축소한 그림"이 된다 |
| 명암 | 2단만. 본체 + 그림자 1단. 그라데이션·질감 없음 | 깔끔하게 읽히는 이유 |
| 외곽선 | 1px, 몸통색을 어둡게 한 색. **검정 금지** | 검정 외곽선은 스티커처럼 보인다 |
| 내부 선 | 없음. 부위 구분은 색 면으로만 | 48px에서 내부 선은 얼룩이 된다 |
| 눈 | 흰자 + 검은 동공 + 1px 하이라이트. 유일한 디테일 | 귀여움의 거의 전부가 눈에서 온다 |
| 등신 | 2~2.5등신. 머리가 몸과 같거나 크다 | 남녀노소 타깃 |
| 실루엣 | 둥근 덩어리 하나. **특징은 하나만**, 8px 이상 튀어나오게 | 48px에서 특징 둘은 둘 다 안 읽힌다 |

색 수는 눈으로 세지 않는다. `flutter/tools/count_colors.py`로 센다.

**팔레트 스왑**: 앱이 `hueRotation`(`flutter/lib/ui/stage/stage_actor.dart`)으로 색상환을 돌려
지역 기본 형태 20종을 100종으로 늘린다. 이 행렬은 휘도를 보존하므로 **무채색을 그대로 둔다**.
따라서 눈과 외곽선을 어둡고 채도 낮게 그리면 스왑에서 자동으로 제외된다. 코드로 막을 것이 없다.
반대로 눈을 채도 높은 색으로 그리면 변종마다 눈 색이 달라져 표정이 무너진다.

**속성 색** (`monster_sprite.dart`의 `elementColor`, 코드와 묶여 있으므로 바꾸지 않는다):
화 `#E85D3A` · 수 `#3B82F6` · 지 `#6B8E23` · 풍 `#2DD4BF` · 무 `#9CA3AF`

**보스**: 같은 실루엣 언어. 96×96 크기와 장식(왕관·문양) 하나만 더한다.
보스만 다른 언어로 그리면 100종 일관성이 거기서 깨진다.

## 2. 생성 프롬프트

세 블록으로 쪼갠다. **① 스타일 블록은 100종 내내 한 글자도 바꾸지 않는다.**
화풍이 흔들리는 것은 거의 항상 스타일 블록을 손댔기 때문이다. 고칠 때는 한 줄씩만 고쳐 다시 뽑는다.

### ① 스타일 블록 (고정)

```
cute minimal pixel art creature sprite, chunky rounded silhouette, exactly 5 colors,
flat fill with a single shadow step, no gradient, no texture, no inner lines,
1px outline in a darker shade of the body color, never black,
big simple eyes, white sclera with one highlight pixel,
2-head-tall chibi proportions, one creature, centered, side view facing east,
transparent background
```

부정 프롬프트:

```
realistic, detailed, noisy, dithering, many colors, gradient, black outline,
multiple creatures, text, background
```

### ② 용 단계 블록

지역이 뒤로 갈수록 용의 특징이 하나씩 더해진다. **더하기만 하고 빼지 않는다.**
마계 몬스터는 뿔·꼬리·날개·비늘을 다 갖는다 — 즉 거의 용이다.

| 단계 | 지역 | 블록 | 팔레트 |
|---|---|---|---|
| 0 | 숲 · 동굴 | (없음) | 밝음, 채도 중간 |
| 1 | 화산 · 설원 · 늪지 | `a pair of small horns` | 채도 올라감 |
| 2 | 사막 · 심해 | `+ a thick tail` — 심해는 `+ a fin` | 어두워지기 시작 |
| 3 | 하늘섬 · 폐허 | `+ small membrane wings` | 금·회색이 섞임 |
| 4 | 마계 | `+ scale-covered body` | 가장 어두움, 진홍 포인트 |

물려받은 특징은 `small` · `faint`를 붙여 눌러 둔다.
마계 예시: `+ scale-covered body, small faint horns, small faint wings`

지역과 층 범위는 `GAME_DESIGN.md` 18.3을 따른다.

### ③ 캐릭터 블록

몬스터 1종의 정체만 한 줄로. `a round mossy boar` · `a chubby lava toad` 처럼.

색은 프롬프트에서 고정하지 않는다. 앱이 팔레트 스왑으로 바꾼다.

주인공 4직업은 사람형이라 ①은 그대로 쓰고 ②는 붙이지 않는다.

### 호출 규칙

`2026-09-03-art-pipeline-design.md` §1을 따른다.
사람형은 표준 모드 + 템플릿 애니메이션, 비인간형은 v3 모드 + v3 커스텀 애니메이션.
**방향은 반드시 하나만 지정한다**(기본이 전 방향이라 4~8배 비용).

화풍 스파이크처럼 **모양만 볼 때는 `create_image_pixflux`(1 generation)**를 쓴다.
리그·애니메이션이 필요 없을 때 `create_character`를 부르는 것은 낭비다.

## 3. 앱에 넣는 절차

- 프레임 PNG 폴더 → `flutter/tools/sheet_pack.py`로 가로 스트립 PNG + JSON으로 묶는다
- 묶인 시트를 `flutter/assets/sprites/<종류>/<id>.png`(+ `.json`)에 둔다.
  종류는 `hero` · `monster` · `boss` · `pet`. 배경은 `flutter/assets/backgrounds/<지역>/`
- `flutter/lib/ui/stage/sheet_loader.dart`의 `SheetLoader`가 시트+JSON을 읽는다. 파일만 갈아 끼우면 호출부는 안 건드린다
- 묶인 시트는 **항상 오른쪽을 본다**. 앱이 적을 좌우 반전한다

## 4. 결정 기록

- 2026-09-03: 목표 화풍을 2D 카툰(용·아기자기한 캐릭터)으로 정함. **폐기됨 — 아래 2026-09-04 참조**
- 2026-09-03: 픽셀아트 파이프라인 확정(`2026-09-03-art-pipeline-design.md`). PixelLab MCP + Flame
- 2026-09-04: 화풍을 **귀엽고 미니멀한 픽셀아트**로 확정. 레퍼런스는 팰월드(실루엣)·드래곤빌리지3(크리처).
  100종 내내 귀여움을 고정하고 진행감은 "용을 닮아 가는" 단계 표로 준다.
  근거와 검토했으나 택하지 않은 안은 `2026-09-04-creature-art-direction-design.md`
EOF
```

- [ ] **Step 3: 옛 규격이 남지 않았는지 확인한다**

```bash
grep -n "512×512\|카툰, 아기자기\|assets/monsters/\|지금은 벡터만\|Midjourney\|히어로 원정대" ART_GUIDE.md
```

기대: **`2D 카툰(용·아기자기한 캐릭터)` 한 줄만 잡힌다** — §4 결정 기록의 폐기 표시가 붙은 이력이라 남긴다. `512×512` · `assets/monsters/` · `지금은 벡터만` · `Midjourney` · `히어로 원정대`는 **하나도 안 잡혀야 한다**. 잡히면 그 줄을 지운다.

- [ ] **Step 4: 참조한 경로가 실제로 있는지 확인한다**

```bash
ls flutter/tools/sheet_pack.py flutter/lib/ui/stage/sheet_loader.dart flutter/lib/ui/stage/stage_actor.dart
ls -d flutter/assets/sprites/monster flutter/assets/backgrounds
grep -n "elementColor" flutter/lib/ui/sprites/monster_sprite.dart | head -1
```

기대: 전부 존재한다. 문서가 없는 파일을 가리키면 다음 사람이 헤맨다.

- [ ] **Step 5: 커밋**

```bash
git add ART_GUIDE.md
git commit -m "docs(art): 화풍 규격을 픽셀로 전면 교체 — 5색·특징 하나·용 단계 표

옛 2D 카툰 규격(512×512, 벡터풍)이 남아 art-pipeline-design.md의 픽셀
규격과 어긋나 있었다. 실제로 생성기에 들어가는 프롬프트 표가 여기라
이걸 두면 무엇을 뽑아도 화풍이 흔들린다.

3절의 사실 오류도 고쳤다 — 에셋 경로가 assets/monsters/가 아니라
assets/sprites/monster/이고, SheetLoader는 이미 붙어 동작한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: GAME_DESIGN.md 18장을 화풍에 맞춘다

**Files:**
- Modify: `GAME_DESIGN.md:496` (18.2 첫 항목의 둘째 문장)
- Modify: `GAME_DESIGN.md:569-574` 부근 (18.8 아직 안 정한 것)

**Interfaces:**
- Consumes: Task 1이 확정한 용 단계 표
- Produces: 세계관과 화풍이 같은 말을 한다는 근거. 이후 지역·펫 발주가 이 문장을 인용한다

18.2는 "뒤로 갈수록 원형을 잃는다"고 적고, 그 한 줄이 100종의 디자인 곡선을 정한다고 선언한다. 새 화풍은 정반대다 — 100종 내내 귀엽고, 대신 용을 닮아 간다. 이 문장을 그대로 두면 발주서 두 개가 서로 반대를 지시한다.

- [ ] **Step 1: 지금 문장을 확인한다**

```bash
sed -n '495,496p' GAME_DESIGN.md
```

기대 출력:

```
1. **용은 멸종하지 않았다. 잠들었다.** 용이 잠들자 마력이 땅으로 스며들어 짐승이 마물이 됐다.
   그래서 앞 지역의 몬스터는 작고 귀엽고, 뒤로 갈수록 원형을 잃는다. 이 한 줄이 100종의 디자인 곡선을 정한다.
```

- [ ] **Step 2: 문장을 뒤집는다**

```bash
python3 - <<'EOF'
import pathlib
p = pathlib.Path('GAME_DESIGN.md')
s = p.read_text()
old = "   그래서 앞 지역의 몬스터는 작고 귀엽고, 뒤로 갈수록 원형을 잃는다. 이 한 줄이 100종의 디자인 곡선을 정한다.\n"
new = ("   그래서 앞 지역의 몬스터는 아무것도 없는 부푼 짐승이고, 뒤로 갈수록 용의 형태를 얻는다 —\n"
       "   뿔이 나고, 꼬리가 붙고, 날개막이 생기고, 마지막에 비늘로 덮인다. 이 한 줄이 100종의 디자인 곡선을 정한다.\n"
       "   귀여움은 100종 내내 고정한다. 남녀노소가 보는 그림이다. 단계 표는 `ART_GUIDE.md` 2절.\n")
assert old in s, "대상 문장을 못 찾았다"
p.write_text(s.replace(old, new))
print("ok")
EOF
```

- [ ] **Step 3: 18.8에서 해결된 항목을 지운다**

18.8의 "지역 보스 10종의 외형 시안(18.3의 이름만 정해졌다)"은 이제 근거가 생겼다 — 단계 표 + 보스 규칙(96×96 + 장식 하나)이 시안의 틀이다. 항목을 지우는 대신 무엇이 남았는지로 바꾼다.

```bash
python3 - <<'EOF'
import pathlib
p = pathlib.Path('GAME_DESIGN.md')
s = p.read_text()
old = "- 지역 보스 10종의 외형 시안(18.3의 이름만 정해졌다)\n"
new = "- 지역 보스 10종의 캐릭터 블록 문안. 화풍 틀은 정해졌다(`ART_GUIDE.md` 1·2절) — 남은 것은 정체를 한 줄로 쓰는 일이다\n"
assert old in s, "대상 문장을 못 찾았다"
p.write_text(s.replace(old, new))
print("ok")
EOF
```

- [ ] **Step 4: 앞뒤가 맞는지 확인한다**

```bash
sed -n '493,503p' GAME_DESIGN.md
grep -n "원형을 잃는다" GAME_DESIGN.md docs/ -r
grep -n "용의 형태를 얻는다" GAME_DESIGN.md
```

기대: 18.2가 새 문장으로 읽히고, `docs/superpowers/specs/2026-09-04-creature-art-direction-design.md` 7절(이 교체를 지시하는 문서)을 빼면 "원형을 잃는다"가 어디에도 안 남는다.

- [ ] **Step 5: 18.4(용과 알)와 충돌하지 않는지 읽는다**

```bash
sed -n '/### 18.4/,/### 18.5/p' GAME_DESIGN.md
```

기대: 18.4는 부화한 것이 "그 지역의 마력이 뭉친 작은 것"이라고 적혀 있다. 지역이 뒤일수록 마력이 용에 가까우므로 펫이 용을 닮아 가는 것도 같은 규칙으로 설명된다. **충돌 없음**을 확인만 하고 문장은 건드리지 않는다. 충돌한다고 판단되면 고치지 말고 멈추고 보고한다 — 세계관 문장은 사용자 결재 사항이다.

- [ ] **Step 6: 커밋**

```bash
git add GAME_DESIGN.md
git commit -m "docs: 18.2를 뒤집는다 — 원형을 잃는 게 아니라 용의 형태를 얻는다

100종 내내 귀여움을 고정하기로 했으므로 '뒤로 갈수록 원형을 잃는다'가
새 화풍과 정면으로 부딪힌다. 진행감은 용의 특징이 하나씩 더해지는
단계 표가 준다. 잠든 용에게 가까워질수록 마물이 용을 닮는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 색 수 검사 도구

**Files:**
- Create: `flutter/tools/count_colors.py`

**Interfaces:**
- Consumes: 없음
- Produces: `count_colors.py <png...> [--max N]` — 종료 코드 0(합격) / 1(불합격). Task 4의 합격 기준 2번이 이걸 부른다

합격 기준 2번은 "색이 5개 이내다 — 스크립트로 센다, 눈으로 안 센다"이다. 그 스크립트가 아직 없다.

`flutter/tools/`의 기존 도구(`sheet_pack.py` · `bg_pixelize.py`)와 같은 방식으로 쓴다 — argparse + Pillow, 테스트 파일 없음. 이 폴더에는 파이썬 테스트 인프라가 없고, 30줄짜리 도구를 위해 들이는 것은 과하다. 대신 Step 3에서 정답을 아는 입력으로 돌려 확인한다.

- [ ] **Step 1: Pillow를 쓸 수 있게 한다**

기존 도구가 이미 PIL을 쓰는데 지금 어느 파이썬에도 설치돼 있지 않다.

```bash
python3 -c "import PIL; print(PIL.__version__)" || python3 -m pip install --user pillow
python3 -c "from PIL import Image; print('ok')"
```

기대: 마지막 줄이 `ok`. 실패하면(외부 관리 환경 오류 등) `python3 -m venv flutter/tools/.venv && flutter/tools/.venv/bin/pip install pillow`로 만들고, 이후 모든 단계에서 `flutter/tools/.venv/bin/python`을 쓴다. 어느 쪽을 골랐는지 커밋 메시지에 적는다.

- [ ] **Step 2: 도구를 쓴다**

```bash
cat > flutter/tools/count_colors.py <<'EOF'
#!/usr/bin/env python3
"""스프라이트의 색 수를 센다. 화풍 규격은 5색 이내(ART_GUIDE.md 1절).

사용: count_colors.py <png...> [--max 5]

투명 픽셀(alpha 0)은 세지 않는다. 반투명 픽셀은 픽셀아트 규격 위반이라 같이 보고하되
합격 여부는 색 수로만 판정한다 — 생성기가 가장자리에 몇 픽셀 남기는 일이 흔하고,
그건 sheet_pack.py 단계에서 정리된다.
"""
import argparse
import sys
from pathlib import Path

from PIL import Image


def count(path: Path) -> tuple[int, int]:
    """(불투명 색 수, 반투명 픽셀 수)를 돌려준다."""
    im = Image.open(path).convert("RGBA")
    colors: set[tuple[int, int, int]] = set()
    semi = 0
    for r, g, b, a in im.getdata():
        if a == 0:
            continue
        if a < 255:
            semi += 1
        colors.add((r, g, b))
    return len(colors), semi


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+", type=Path)
    ap.add_argument("--max", type=int, default=5, help="허용 색 수 (기본 5)")
    args = ap.parse_args()

    failed = False
    for p in args.paths:
        n, semi = count(p)
        ok = n <= args.max
        failed |= not ok
        note = f", 반투명 {semi}px" if semi else ""
        print(f"{'OK  ' if ok else '실패'} {p.name}: {n}색{note}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
EOF
chmod +x flutter/tools/count_colors.py
```

- [ ] **Step 3: 정답을 아는 입력으로 돌린다**

3색짜리 PNG를 만들어 3색으로 세는지 본다. 반투명 픽셀과 투명 픽셀도 같이 넣어 규칙이 맞는지 확인한다.

```bash
python3 - <<'EOF'
from PIL import Image
im = Image.new("RGBA", (4, 4), (0, 0, 0, 0))          # 투명 — 안 센다
im.putpixel((0, 0), (255, 0, 0, 255))                  # 빨강
im.putpixel((1, 0), (0, 255, 0, 255))                  # 초록
im.putpixel((2, 0), (0, 0, 255, 255))                  # 파랑
im.putpixel((3, 0), (0, 0, 255, 128))                  # 파랑 반투명 — 색은 중복, 반투명 1px
im.save("/tmp/three.png")
EOF
python3 flutter/tools/count_colors.py /tmp/three.png --max 5; echo "종료코드=$?"
python3 flutter/tools/count_colors.py /tmp/three.png --max 2; echo "종료코드=$?"
```

기대 출력:

```
OK   three.png: 3색, 반투명 1px
종료코드=0
실패 three.png: 3색, 반투명 1px
종료코드=1
```

세 가지가 다 맞아야 한다 — 투명은 안 세고, 반투명은 색을 중복으로 안 세고 보고만 하고, `--max`가 종료 코드를 가른다.

- [ ] **Step 4: 실제 스프라이트로 돌려 지금 위치를 잰다**

```bash
python3 flutter/tools/count_colors.py flutter/assets/sprites/monster/forest_1.png flutter/assets/sprites/hero/warrior_1.png --max 5; echo "종료코드=$?"
```

기대: **실패해도 정상이다.** 지금 스프라이트는 새 규격 이전에 뽑은 것이라 5색을 한참 넘을 가능성이 높다. 이 단계의 목적은 도구가 실제 시트에서 도는지 보는 것과, 지금 색 수가 몇인지 기록해 Task 4의 개선 폭을 재는 것이다. **숫자를 적어 둔다.**

- [ ] **Step 5: 커밋**

```bash
git add flutter/tools/count_colors.py
git commit -m "tools: 스프라이트 색 수 검사 — 눈으로 안 세고 기계로 센다

화풍 규격이 1종당 5색이다. 합격 판정을 눈으로 하면 흔들린다.
투명은 안 세고, 반투명은 규격 위반이라 보고만 하고 판정에서는 뺀다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: PixelLab 4마리 화풍 스파이크

**Files:**
- Create (임시): `<scratchpad>/art-spike/` 아래 PNG 4개 + 팔레트 스왑 변종 2개
- 프로젝트 트리에 넣지 않는다. **판정용이고 출시 물량이 아니다**

**Interfaces:**
- Consumes: Task 1의 스타일 블록·용 단계 블록, Task 3의 `count_colors.py`
- Produces: 사용자의 합격/불합격 판정. 합격이면 Task 5가 기록하고, 불합격이면 이 태스크를 다시 돈다

**⚠️ 이 태스크는 유료다.** PixelLab은 크레딧제다. Step 1의 잔액을 사용자에게 보이고 **진행 승인을 받은 뒤에** Step 3으로 간다. 승인 없이 생성하지 않는다.

리그와 애니메이션이 필요 없으므로 `create_character`(v3, 2~9 generations)가 아니라 `create_image_pixflux`(1 generation)를 쓴다. 판정 대상은 화풍이지 방향 회전이 아니다. **4장 = 4 generations.**

- [ ] **Step 1: 잔액을 확인하고 사용자에게 보인다**

`get_balance`를 부른다. 남은 크레딧과 구독 생성 횟수를 사용자에게 그대로 보고하고, "4 generations를 쓰겠다"고 말한 뒤 승인을 기다린다.

- [ ] **Step 2: 프롬프트 4개를 조립해 사용자에게 보인다**

`ART_GUIDE.md` 2절의 ①+②+③을 이어 붙인다. 스타일 블록은 네 번 다 똑같아야 한다.

| # | 지역 | 단계 | ③ 캐릭터 블록 | ② 용 단계 블록 |
|---|---|---|---|---|
| 1 | 숲 | 0 | `a round mossy boar` | (없음) |
| 2 | 화산 | 1 | `a chubby lava toad` | `a pair of small horns` |
| 3 | 심해 | 2 | `a plump deep-sea jelly creature` | `+ a fin` |
| 4 | 마계 | 4 | `a stout shadow beast` | `+ scale-covered body, small faint horns, small faint wings, small faint tail` |

단계 3(하늘섬·폐허, 날개막)을 뺀 것은 의도다 — 날개막은 단계 4에 포함되므로 마계 한 마리로 같이 검사된다. 마계에서 날개가 안 읽히면 3과 4를 갈라 다시 뽑는다.

조립 결과 4줄을 사용자에게 보여 오타·누락을 먼저 잡는다.

- [ ] **Step 3: 4장을 생성한다**

`create_image_pixflux`를 4번 부른다. 네 번 모두 같은 값:

- `description`: Step 2에서 조립한 줄 (스타일 블록 + 용 단계 블록 + 캐릭터 블록)
- `width: 48`, `height: 48`
- `no_background: true`
- `view: "side"`, `direction: "east"`
- `outline: "single color outline"` — 검정 금지이므로 `single color black outline`이 아니다
- `shading: "flat shading"`
- `detail: "low detail"`

비동기다. 4개를 한꺼번에 걸고 `get_image(job_id)`로 받는다. 받은 PNG를 scratchpad의 `art-spike/1-forest.png` … `4-abyss.png`로 저장한다.

- [ ] **Step 4: 합격 기준 2번을 기계로 잰다**

```bash
python3 flutter/tools/count_colors.py <scratchpad>/art-spike/*.png --max 5; echo "종료코드=$?"
```

기대: 종료 코드 0. **떨어질 가능성이 가장 높은 기준이다** — 생성기가 색 수를 잘 안 지킨다. 떨어지면 Step 7로 간다.

- [ ] **Step 5: 팔레트 스왑 변종을 만든다 (합격 기준 4번)**

앱과 같은 휘도 보존 색상 회전을 숲 몬스터에 걸어 변종 2개를 만든다. 행렬은 `flutter/lib/ui/stage/stage_actor.dart:201` `hueRotation`과 같은 식이다.

```bash
python3 - <<'EOF'
import math
from PIL import Image

SRC = "<scratchpad>/art-spike/1-forest.png"

def hue_matrix(deg):
    """stage_actor.dart의 hueRotation과 같은 행렬. 휘도를 보존한다."""
    r = math.radians(deg); c, s = math.cos(r), math.sin(r)
    lr, lg, lb = 0.213, 0.715, 0.072
    return [
        [lr + c*(1-lr) - s*lr,      lg - c*lg - s*lg,        lb - c*lb + s*(1-lb)],
        [lr - c*lr + s*0.143,       lg + c*(1-lg) + s*0.140, lb - c*lb - s*0.283],
        [lr - c*lr - s*(1-lr),      lg - c*lg + s*lg,        lb + c*(1-lb) + s*lb],
    ]

def rotate(path, deg, out):
    m = hue_matrix(deg)
    im = Image.open(path).convert("RGBA")
    px = []
    for r, g, b, a in im.getdata():
        if a == 0:
            px.append((0, 0, 0, 0)); continue
        v = [max(0, min(255, round(row[0]*r + row[1]*g + row[2]*b))) for row in m]
        px.append((v[0], v[1], v[2], a))
    out_im = Image.new("RGBA", im.size); out_im.putdata(px); out_im.save(out)
    print("wrote", out)

rotate(SRC, 120, SRC.replace("1-forest", "1-forest-hue120"))
rotate(SRC, 240, SRC.replace("1-forest", "1-forest-hue240"))
EOF
```

- [ ] **Step 6: 대조 시트를 만들어 판정을 받는다**

**스펙과 다른 점을 먼저 밝힌다.** 스펙 §5-4는 "실기기 캡처"라고 적었지만, 이 스파이크 산출물은 앱에 넣지 않는다(Step 8). 넣으려면 시트로 묶고 `pubspec.yaml`에 등록하고 되돌려야 하는데, 화풍 판정에 그만한 비용을 들일 이유가 없다. 대신 **원본 크기 줄과 4배 확대 줄을 한 장에 담은 대조 시트**로 판정한다. 원본 줄이 무대에서의 실제 크기이고, 확대 줄이 픽셀 규격을 보는 용도다.

실기기 캡처는 **합격 후 첫 물량 1종을 뽑을 때** 한다(아래 "알려진 위험"의 v3 확인과 같은 시점).

```bash
python3 - <<'EOF'
from PIL import Image
from pathlib import Path

D = Path("<scratchpad>/art-spike")
names = ["1-forest", "2-volcano", "3-abyssal-sea", "4-abyss", "1-forest-hue120", "1-forest-hue240"]
ims = [Image.open(D / f"{n}.png").convert("RGBA") for n in names]

pad, scale = 8, 4
w = max(i.width for i in ims)
sheet_w = len(ims) * (w * scale + pad) + pad
sheet_h = pad + w + pad + w * scale + pad
sheet = Image.new("RGBA", (sheet_w, sheet_h), (24, 24, 28, 255))

for k, im in enumerate(ims):
    x = pad + k * (w * scale + pad)
    sheet.paste(im, (x + (w * scale - im.width) // 2, pad), im)          # 원본 크기 줄
    big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)  # 4배 확대 줄
    sheet.paste(big, (x, pad + w + pad), big)

out = D / "contact-sheet.png"
sheet.save(out)
print("wrote", out, sheet.size)
EOF
```

대조 시트를 사용자에게 보낸다(`SendUserFile`). 다섯 줄을 그대로 묻는다. 판정은 사용자가 한다.

1. 4마리를 나란히 놓으면 **같은 게임**으로 보이는가
2. 색이 5개 이내인가 — Step 4의 출력을 그대로 붙인다
3. 48px에서 **눈과 새로 더해진 특징**이 읽히는가
4. 팔레트 스왑 뒤에도 **눈과 외곽선 색이 안 바뀌는가** — 변종 2장으로 확인
5. 숲과 마계가 "그냥 다른 것"이 아니라 **"닮아 가는 관계"**로 읽히는가

- [ ] **Step 7: 떨어졌으면 고치고 다시 돈다**

- **기준 1~4에서 떨어짐**: `ART_GUIDE.md` 2절 스타일 블록을 **한 줄씩만** 고쳐 Step 1부터 다시 돈다. 여러 줄을 한꺼번에 고치면 무엇이 고쳤는지 모른다. 잔액 승인도 다시 받는다
- **기준 5에서 떨어짐**: 단계 표(`ART_GUIDE.md` 2절 ②)가 틀린 것이다. 표를 고치고 다시 돈다
- 어느 쪽이든 **고친 이유와 결과를 Task 5의 결정 기록에 남긴다**

- [ ] **Step 8: 산출물을 버린다**

스파이크 그림은 커밋하지 않는다. scratchpad에 두고 끝낸다. 프로젝트 트리에 옮기면 다음 사람이 출시 물량으로 오해한다.

---

### Task 5: 판정 결과를 기록하고 다음을 연다

**Files:**
- Modify: `ART_GUIDE.md` §4 결정 기록
- Modify: `docs/superpowers/specs/2026-09-04-creature-art-direction-design.md` §8
- Modify: `docs/BACKLOG.md` D절

**Interfaces:**
- Consumes: Task 4의 판정 결과
- Produces: 다음 작업(지역별 기본 형태 20종 발주)이 시작할 수 있는 상태

Task 4가 **합격했을 때만** 이 태스크를 돈다. 불합격이면 Task 4로 돌아간다.

- [ ] **Step 1: ART_GUIDE 결정 기록에 검증 결과를 적는다**

`## 4. 결정 기록` 아래에 한 줄 더한다. 실제 숫자를 넣는다 — "합격"만 적으면 다음 사람이 무엇을 통과했는지 모른다.

```
- 2026-09-04: 화풍 검증 합격. `create_image_pixflux` 4장(숲0·화산1·심해2·마계4), 색 수 <실제 값>,
  팔레트 스왑 120°·240°에서 눈·외곽선 유지 확인. 스타일 블록 수정 <횟수>회.
  다음: 지역별 기본 형태 20종(지역 5 × 형태 4)의 캐릭터 블록 문안
```

- [ ] **Step 2: 스펙 8절에서 풀린 항목을 지운다**

두 항목이 이번에 풀렸다.

- "팔레트 스왑에서 눈·외곽선을 제외하는 규칙이 지금 코드에 있는지" → **코드 작업이 아니다.** `hueRotation`이 휘도 보존이라 무채색을 그대로 둔다. 어둡고 채도 낮게 그리면 자동 충족
- Task 4가 통과했으므로 화풍 자체는 확정

```bash
python3 - <<'EOF'
import pathlib
p = pathlib.Path('docs/superpowers/specs/2026-09-04-creature-art-direction-design.md')
s = p.read_text()
old = "- 팔레트 스왑에서 눈·외곽선을 제외하는 규칙이 지금 코드에 있는지 — 구현 계획에서 확인한다\n"
new = ("- ~~팔레트 스왑에서 눈·외곽선을 제외하는 규칙~~ — 코드 작업이 아니었다.\n"
       "  `stage_actor.dart`의 `hueRotation`이 휘도 보존 행렬이라 무채색을 그대로 둔다.\n"
       "  눈·외곽선을 어둡고 채도 낮게 그리면 자동 충족된다 (2026-09-04 확인)\n")
assert old in s, "대상 문장을 못 찾았다"
p.write_text(s.replace(old, new))
print("ok")
EOF
```

- [ ] **Step 3: BACKLOG D절에 화풍 확정을 반영한다**

D1(구매 전 규격 검토)은 외부 구매를 전제로 쓴 항목인데, 화풍이 정해지고 생성 경로가 PixelLab으로 확정됐으므로 성격이 바뀐다. D3(스프라이트 교체)의 선행 조건도 이제 명확하다.

`## D. 아트 (유료 구매 뒤)` 절 머리에 다음을 넣는다.

```
**2026-09-04: 화풍 확정.** 귀엽고 미니멀한 픽셀아트, 뒤로 갈수록 용을 닮아 간다.
규격과 프롬프트는 `ART_GUIDE.md`, 근거는 `docs/superpowers/specs/2026-09-04-creature-art-direction-design.md`.
D1의 "구매 전 규격 검토"는 외부 구매를 전제로 쓴 항목이다. 생성 경로가 PixelLab으로 정해졌으므로
외부 팩을 살 때만 쓴다. 지금 남은 것은 지역별 기본 형태 20종의 캐릭터 블록 문안이다.
```

- [ ] **Step 4: 문서 셋이 서로 안 어긋나는지 읽는다**

```bash
grep -n "5색\|다섯 색" ART_GUIDE.md docs/superpowers/specs/2026-09-04-creature-art-direction-design.md
grep -n "용의 형태를 얻는다\|원형을 잃는다" GAME_DESIGN.md ART_GUIDE.md docs/ -r
grep -rn "512×512" ART_GUIDE.md GAME_DESIGN.md docs/
```

기대: 색 수는 세 문서에서 다 5색이고, "원형을 잃는다"는 스펙 7절(교체를 지시하는 문서)에만 남고, `512×512`는 어디에도 없다.

- [ ] **Step 5: 커밋**

```bash
git add ART_GUIDE.md GAME_DESIGN.md docs/
git commit -m "docs(art): 화풍 검증 합격 기록 — 다음은 기본 형태 20종

4장(숲0·화산1·심해2·마계4)으로 다섯 기준을 통과했다.
팔레트 스왑 미결 항목은 코드 작업이 아니었다 — hueRotation이
휘도 보존이라 눈·외곽선을 어둡게 그리면 자동으로 제외된다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## 꺾쇠 표기

계획 안의 `<scratchpad>` · `<실제 값>` · `<횟수>`는 **실행할 때 채우는 자리**다. 미정 항목이 아니다.

- `<scratchpad>`: 이 세션의 scratchpad 경로. 세션마다 다르다
- `<실제 값>` · `<횟수>`: Task 4에서 실제로 나온 숫자. 그대로 두고 커밋하면 안 된다

## 이 계획이 하지 않는 것

- **지역별 기본 형태 20종 생성.** 화풍이 합격한 뒤의 다음 작업이다. 캐릭터 블록 20줄을 먼저 써야 하고 그건 별도 발주다
- **배경.** `2026-09-03-art-pipeline-design.md`가 별도 경로(`create_image_pixflux` 360×272)로 잡아 뒀다. 세로 배경 10지역(백로그 D2)은 이 검증이 끝난 뒤 같은 규격으로
- **이펙트(VFX) 화풍.** 스펙이 캐릭터만 다룬다
- **콘텐츠 축.** 레퍼런스에서 화면 문법은 가져왔지만 콘텐츠(전용무기 축·영지·동료·던전 추가)는 안 가져왔다. 백로그 F의 보류 결정과 부딪히므로 별도 설계가 필요하다
- **코드 변경.** 이 계획에는 Dart 수정이 없다. `count_colors.py` 하나만 새로 생긴다

## 알려진 위험

| 위험 | 어디서 터지나 | 대응 |
|---|---|---|
| 생성기가 5색을 안 지킨다 | Task 4 Step 4 | 가장 떨어질 확률이 높다. 스타일 블록의 `exactly 5 colors`를 한 줄만 고쳐 다시 뽑는다 |
| 마계(단계 4)가 "특징 하나" 규칙과 부딪힌다 | Task 4 Step 6 기준 3 | 물려받은 특징의 `small faint`를 더 강하게 누르거나, 단계 표에서 마계의 비늘을 몸통 질감이 아니라 등줄기로 한정한다 |
| `create_image_pixflux` 화풍이 `create_character` 화풍과 다르다 | 합격 이후 첫 물량 | 스파이크는 1 generation짜리 도구로 싸게 봤다. 합격 후 **첫 물량 1종을 v3로 뽑아 화풍이 유지되는지 한 번 더 확인**한다. 다르면 스타일 블록을 v3 기준으로 다시 맞춘다 |
| Pillow 설치가 막힌다 | Task 3 Step 1 | `flutter/tools/.venv`를 만들어 거기에 설치하고, 어느 쪽을 골랐는지 커밋 메시지에 적는다 |
