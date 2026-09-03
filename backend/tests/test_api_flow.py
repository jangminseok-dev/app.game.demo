"""라우터·DI·인증 가드 배선 검증 — DB 없이 스텁 저장소로 게스트 → load → sync 왕복.

인터랙터 로직은 각 앱 테스트가 맡고, 여기는 HTTP 표면(스키마·상태코드·토큰 흐름)만 본다.
"""

from __future__ import annotations

from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession

import main
from auth.app.ports.output.player_repository import PlayerRecord
from auth.adapter.outbound.jwt_token_issuer_adapter import JwtTokenIssuerAdapter
from auth.app.use_cases.guest_interactor import GuestInteractor
from auth.dependencies.guest_provider import get_guest_use_case
from core.security import get_current_player_id
from save.app.use_cases.load_interactor import LoadInteractor
from save.app.use_cases.sync_interactor import SyncInteractor
from save.dependencies.load_provider import get_load_use_case
from save.dependencies.sync_provider import get_sync_use_case
from save.tests.support import StubBalance, StubCodex, StubRejections, StubSaves


class _Players:
    def __init__(self):
        self.rows = {}

    async def find_by_device_id(self, device_id):
        return self.rows.get(device_id)

    async def create(self, device_id):
        rec = PlayerRecord(id=len(self.rows) + 1, device_id=device_id, created_at=datetime.now(UTC))
        self.rows[device_id] = rec
        return rec


@pytest.fixture
def client():
    players = _Players()
    saves = StubSaves()
    issuer = JwtTokenIssuerAdapter()

    async def fake_guard(credentials=None, db: AsyncSession | None = None):
        # 실제 가드는 DB로 players를 확인한다. 여기서는 서명 검증만 재사용한다.
        import jwt
        from fastapi import HTTPException, Request  # noqa: F401
        from core.config import JWT_SECRET
        from core.security import JWT_ALGORITHM
        if credentials is None:
            raise HTTPException(status_code=401, detail="인증이 필요합니다.")
        return int(jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])["sub"])

    from fastapi import Depends
    from core.security import _bearer

    async def guard(credentials=Depends(_bearer)):
        return await fake_guard(credentials)

    main.app.dependency_overrides[get_guest_use_case] = lambda: GuestInteractor(players=players, tokens=issuer)
    main.app.dependency_overrides[get_load_use_case] = lambda: LoadInteractor(saves=saves, balance=StubBalance(), codex=StubCodex())
    main.app.dependency_overrides[get_sync_use_case] = lambda: SyncInteractor(
        saves=saves, balance=StubBalance(), rejections=StubRejections(), codex=StubCodex()
    )
    main.app.dependency_overrides[get_current_player_id] = guard
    # lifespan(DB 엔진)은 띄우지 않는다 — TestClient를 컨텍스트 없이 쓴다.
    yield TestClient(main.app)
    main.app.dependency_overrides.clear()
    main.app.dependency_overrides.update(main.HUB_BINDINGS)


def test_자기소개_4종은_인증_없이_열려_있다(client):
    for path in ("/auth/myself", "/save/myself", "/masterdata/myself", "/codex/myself"):
        r = client.get(path)
        assert r.status_code == 200, path
        assert "introduction" in r.json()


def test_마스터데이터는_인증_없이_버전과_계수를_준다(client):
    r = client.get("/masterdata/balance")
    assert r.status_code == 200
    body = r.json()
    assert body["version"] == 4 and body["monsterHpGrowth"] == 1.18
    assert client.get("/masterdata/balance", params={"version": 4}).json()["unchanged"] is True
    monsters = client.get("/masterdata/monsters").json()
    assert len(monsters["monsters"]) == 100 and len(monsters["regions"]) == 10


def test_세이브는_토큰_없이_막힌다(client):
    assert client.get("/save").status_code == 401
    assert client.put("/save", json={"state": {}}).status_code == 401


def test_게스트_시작_후_load와_sync_왕복(client):
    guest = client.post("/auth/guest", json={"deviceId": "device-1"})
    assert guest.status_code == 200
    token = guest.json()["accessToken"]
    assert guest.json()["created"] is True
    auth = {"Authorization": f"Bearer {token}"}

    # sync 먼저 부르면 409 — load가 초기 세이브를 만든다
    assert client.put("/save", json={"state": {"stage": 1, "highestStage": 1, "gold": 0}}, headers=auth).status_code == 409

    loaded = client.get("/save", headers=auth)
    assert loaded.status_code == 200
    assert loaded.json()["created"] is True
    assert loaded.json()["offlineReward"] is None
    assert loaded.json()["codex"] == []
    state = loaded.json()["state"]

    state.update({"gold": 30, "totalKills": 6, "levels": {"attack": 1}})
    synced = client.put("/save", json={"state": state}, headers=auth)
    assert synced.status_code == 200
    assert synced.json()["accepted"] is True
    assert synced.json()["captures"] == []

    state.update({"gold": 10**9})
    rejected = client.put("/save", json={"state": state}, headers=auth)
    assert rejected.status_code == 200
    assert rejected.json()["accepted"] is False
    assert rejected.json()["rejectedRule"] == "gold_conservation"
    assert rejected.json()["state"]["gold"] == 30

    assert client.put("/save", json={"state": {"stage": "x"}}, headers=auth).status_code == 400
    assert client.post("/auth/guest", json={"deviceId": "   "}).status_code == 400
