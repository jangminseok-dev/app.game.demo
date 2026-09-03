# 아트 가이드 — 스타일 규격과 AI 생성 프롬프트

목표 화풍: **2D 카툰, 아기자기한 캐릭터, 용이 나오는 판타지** (레퍼런스: 히어로 원정대 수준. AFK Arena급은 목표가 아니다).
이 문서는 ① 어떤 경로로 만들든 지켜야 할 규격, ② AI 이미지 생성기(Midjourney·Stable Diffusion·Ideogram 등)에 넣을 프롬프트, ③ 결과물을 앱에 넣는 절차를 적는다.

## 1. 규격 (경로 무관)

| 항목 | 값 |
|---|---|
| 캔버스 | 정사각 **512×512** 원본 → 앱에서 96·110·132·150으로 축소. 투명 배경(PNG) |
| 시점 | 정면 3/4, 살짝 위에서 내려다봄. 몬스터는 **왼쪽(주인공 쪽)을 본다**, 주인공은 오른쪽을 본다 |
| 비율 | 2등신. 머리가 몸보다 크거나 같다. 눈은 크고 흰자·하이라이트가 있다 |
| 선 | 두께 있는 진한 외곽선(몸통색을 어둡게 한 색, 검정 아님). 내부 선은 최소 |
| 채색 | 플랫 + 그림자 1단. 그라데이션·질감 없음. 발밑에 타원 그림자 |
| 팔레트 | 몬스터당 **5색 이내**: 몸통 / 배·밝은 면 / 외곽선 / 포인트(뿔·날개막) / 눈. 속성 기본색은 `monster_sprite.dart`의 `elementColor` |
| 속성 색 | 화 `#E85D3A` · 수 `#3B82F6` · 지 `#6B8E23` · 풍 `#2DD4BF` · 무 `#9CA3AF` |
| 파일명 | `assets/monsters/<id>.png` (id는 `monsters.json`), 주인공 `assets/hero/idle.png` |

**팔레트 스왑 전제**: 지역당 기본 형태 2~3개를 만들고 나머지는 앱이 색을 바꿔 변종을 만든다. 그래서 형태의 실루엣이 서로 뚜렷이 달라야 하고, 색은 프롬프트에서 고정하지 않아도 된다(앱이 바꾼다). 단 **눈·외곽선은 색 변경에서 제외**되므로 어두운 색으로 통일.

## 2. AI 생성 프롬프트

같은 화풍을 유지하려면 **스타일 블록을 고정**하고 캐릭터 블록만 바꾼다. 영어 프롬프트가 결과가 안정적이다.

### 스타일 블록 (모든 이미지에 동일)

```
cute chibi 2D cartoon game sprite, flat colors with one-step cel shading, thick dark outline,
big glossy eyes with highlight, rosy cheeks, 3/4 front view facing left, full body centered,
plain white background, no text, no watermark, mobile idle RPG character art, clean vector look,
consistent style, single character
```

부정 프롬프트(지원하는 도구에서):

```
realistic, 3D render, photo, gradient shading, painterly, multiple characters, cropped, text, logo, blurry, dark background
```

### 캐릭터 블록 예시

| id | 이름 | 캐릭터 블록 |
|---|---|---|
| 1 | 초록 슬라임 | `a round green slime blob with a tiny leaf on top, happy expression` |
| 10 | 고목의 수호자 | `an ancient tree guardian golem made of mossy bark, kind old face, small glowing eyes, imposing but friendly` |
| 30 | 화산 용왕 | `a baby dragon king, red-orange scales, small golden crown, tiny wings, proud grin, wisps of smoke from nostrils` |
| 70 | 심해왕 크라켄 | `a chubby baby kraken with four stubby tentacles, deep blue, a small pearl crown, mischievous smile` |
| 80 | 하늘섬의 수호룡 | `a sky-blue baby dragon with cloud-like fluffy wings, serene expression, floating pose` |
| 99 | 어둠 비룡 | `a dark purple baby wyvern with bat wings, one glowing violet eye, sly smirk` |
| 주인공 | — | `a small brave knight kid with brown messy hair, blue tunic, round wooden shield, short sword held up, determined smile, facing right` |

희귀(0.3) 몬스터는 `small crown` 또는 `regal`을, 보스 변형은 앱이 왕관·테두리·크기로 처리하므로 별도 생성 불필요.

### 뽑는 순서

1. 스타일 블록 + 주인공으로 4~8장 뽑아 **마음에 드는 화풍 하나를 고른다**. 그 이미지를 이후 생성의 스타일 레퍼런스(image prompt / style reference)로 고정한다.
2. 지역별 기본 형태 2~3종만 뽑는다(총 20~30장). 나머지 변종은 앱 팔레트 스왑.
3. 배경 제거 → 512×512 정사각 크롭 → `assets/monsters/<id>.png`.

## 3. 앱에 넣는 절차

- `flutter/assets/monsters/` 폴더에 `<id>.png`를 두고 `pubspec.yaml`의 assets에 폴더를 등록한다.
- `MonsterSprite`가 PNG가 있으면 그것을, 없으면 코드 벡터(`MonsterPainter`·`DragonPainter`)를 그리도록 되어 있다(PNG 로더는 첫 에셋이 들어올 때 붙인다 — 지금은 벡터만).
- 팔레트 스왑은 앱이 `ColorFilter`로 색상환을 돌린다. 눈·외곽선이 어두우면 영향이 거의 없다.

## 4. 결정 기록

- 2026-09-03: 목표 화풍을 2D 카툰(용·아기자기한 캐릭터)으로 정함. AFK Arena급은 도구·예산 밖.
- 코드 벡터 스파이크: `dragon_painter.dart`(아기 용), `hero_painter.dart`(주인공). 코드 아트의 상한을 보는 용도.
- 남은 결정: AI 생성 vs 에셋 팩 vs 벡터. 위 프롬프트로 5종을 뽑아 앱에 나란히 놓고 결정한다.
