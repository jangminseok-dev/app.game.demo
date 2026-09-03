# blog/ — 개발 기록 블로그

Jekyll 4.4 기반. 게임 코드와 독립이며, 이 디렉토리 안의 파일만 사이트로 빌드된다.
스킨은 redoceanmap 블로그의 카드뉴스 × 다크 리퀴드 글래스를 그대로 가져왔다.

```bash
cd blog
bundle install                          # 최초 1회
bundle exec jekyll serve --port 4200    # http://127.0.0.1:4200 (4000·4100은 타 프로젝트)
```

- 포스트: `_posts/YYYY-MM-DD-제목.markdown` — 주차별 리뷰 형식(무엇을 / 왜 / 어떻게 / 아쉬운 점)
- 빌드 산출물 `_site/`·`.jekyll-cache/`는 gitignore 처리됨 — 커밋 금지
- 공개 호스팅: 도메인 구매 후 `blog.<도메인>` 서브도메인 + S3 정적 웹사이트 + Cloudflare 프록시 (GAME_DESIGN 17장 결정)

## 카드뉴스 형식 (전 페이지 공통)

페이지 = 큰 둥근 카드들의 그리드다. 스타일은 `assets/main.scss`, 스크린샷 카드는 `_includes/card.html`.

```markdown
<div class="cn-grid">

<div class="cn-card cn-bg-dark cn-statement cn-wide">   <!-- 문구 카드 -->
  <p class="cn-label">라벨</p>
  <h2>큰 문구</h2>
  <p>설명 한 줄</p>
</div>

{% include card.html img="/assets/img/week1.png" bg="sage"
   title="1주차 텍스트 화면" desc="숫자만으로 벽이 생기는지 확인했다" %}

<div class="cn-card cn-bg-plain cn-body" markdown="1">   <!-- 텍스트/표 카드 -->
## 소제목
마크다운 내용 (`markdown="1"` 필수)
</div>

</div>
```

- 카드 배경: `cn-bg-warm`(기본) · `cn-bg-sage` · `cn-bg-dark` · `cn-bg-plain`(읽기용)
- 전체 폭 카드: `cn-wide` / include에는 `wide=true`
- card.html 파라미터: `img`(필수) · `title`(필수) · `desc` · `alt` · `bg`
- 이미지는 `assets/img/`에 두고, 캡션은 기능 나열이 아니라 **"어떤 문제를 어떤 결정으로 풀었는지"** 1문장
- 쇼케이스 층(캡션·문구 카드)은 해요체, 문서 본문·리뷰는 다체
- 스크린샷에 키·IP·개인정보가 들어가지 않게 검수한다
