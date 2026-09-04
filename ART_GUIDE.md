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

물려받은 특징은 `small` · `faint`를 붙여 눌러 둔다. **빼지 않는다** — 단계 4는 1·2·3을 다 물려받는다.
마계 예시: `+ scale-covered body, small faint horns, small faint tail, small faint wings`

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
