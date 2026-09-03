import os
import sys
from contextlib import asynccontextmanager

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "apps"))

from fastapi import FastAPI, Response  # noqa: E402

from auth.adapter.inbound.api.v1.guest_router import guest_router  # noqa: E402
from auth.adapter.inbound.api.v1.registrar_router import registrar_router  # noqa: E402
from core.database import dispose_engine, init_engine  # noqa: E402
from core.database import ping as database_ping  # noqa: E402
from hub.dependencies.balance_provider import get_balance_port  # noqa: E402
from masterdata.adapter.inbound.api.v1.almanac_router import almanac_router  # noqa: E402
from masterdata.adapter.inbound.api.v1.balance_router import balance_router  # noqa: E402
from masterdata.dependencies.balance_provider import get_balance_gateway  # noqa: E402
from save.adapter.inbound.api.v1.load_router import load_router  # noqa: E402
from save.adapter.inbound.api.v1.sync_router import sync_router  # noqa: E402
from save.adapter.inbound.api.v1.vault_router import vault_router  # noqa: E402


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_engine()
    try:
        yield
    finally:
        await dispose_engine()


app = FastAPI(title="Idle Fantasy API", lifespan=lifespan)

# 공개 — 게스트 시작·자기소개·마스터 데이터. 인증이 필요한 라우터(save)는 라우터 안에서
# get_current_player_id를 의존성으로 받는다.
app.include_router(guest_router)
app.include_router(registrar_router)
app.include_router(balance_router)
app.include_router(almanac_router)
app.include_router(load_router)
app.include_router(sync_router)
app.include_router(vault_router)

# 합성 루트: 허브 포트에 스포크 구현을 주입한다 (허브는 스포크를 모른다 — 여기만 둘을 안다).
app.dependency_overrides[get_balance_port] = get_balance_gateway


@app.get("/health")
async def health(response: Response):
    db_ok = await database_ping()
    response.status_code = 200 if db_ok else 503
    return {"status": "ok" if db_ok else "degraded", "checks": {"database": db_ok}}


if __name__ == "__main__":
    import uvicorn

    # 8000은 이 맥에서 VS Code가 redoceanmap 백엔드 PC로 포워딩하는 포트라 비켜 간다.
    uvicorn.run("main:app", host="127.0.0.1", port=8010, reload=True)
