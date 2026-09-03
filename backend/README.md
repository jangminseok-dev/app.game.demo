# backend/ — 게임 API (FastAPI)

redoceanmap 백엔드와 같은 구조: 앱 내부는 헥사고날(adapter → app → domain), 앱 사이는 허브-스포크,
슬라이스당 라우터·스키마·DTO·포트·인터랙터·프로바이더·테스트 1개씩. `.importlinter`가 강제한다.

| 앱 | 역할 | 슬라이스 |
|---|---|---|
| hub | 앱 간 계약(포트+DTO)만 소유 | `BalancePort` (masterdata 구현 → save 소비) |
| auth | 계정·토큰 | `guest` POST /auth/guest · `registrar` GET /auth/myself |
| save | 클라우드 세이브 | `load` GET /save · `sync` PUT /save · `vault` GET /save/myself |
| masterdata | 밸런스 계수 | `balance` GET /masterdata/balance · `almanac` GET /masterdata/myself |

```bash
# 최초 1회
cp .env.example .env            # 비밀번호·JWT_SECRET 채우기 (저장소 루트)
cd backend && ~/.pyenv/versions/3.13.13/bin/python -m venv .venv && .venv/bin/pip install -r requirements-dev.txt

# DB (127.0.0.1:5440 — 5432는 다른 프로젝트가 쓴다)
docker compose up -d postgres
cd backend && .venv/bin/alembic upgrade head

# 실행 / 검증
.venv/bin/uvicorn main:app --reload --port 8010           # http://127.0.0.1:8010/docs (8000은 VS Code 포워딩이 점유)
.venv/bin/python -m pytest -q                             # 단위 + API 배선 (DB 불필요)
PYTHONPATH=apps .venv/bin/lint-imports --config .importlinter   # 아키텍처 계약 5종
```

- 비밀값은 `core/key/secret_manager.py` 한 곳에서만 `.env`를 읽는다. 런타임은 `core/config.py` 상수만 쓴다.
- 새 ORM은 `alembic/env.py`에 import 한 줄을 추가해야 마이그레이션 오토젠이 본다.
- 밸런스 계수 정본은 `apps/masterdata/resources/balance.json`. Flutter `BalanceConfig`와 필드가 1:1.
