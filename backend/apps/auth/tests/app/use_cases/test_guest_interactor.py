from datetime import UTC, datetime

import pytest

from auth.app.dtos.guest_dto import GuestCommand
from auth.app.ports.output.player_repository import PlayerRecord
from auth.app.use_cases.guest_interactor import GuestInteractor
from auth.domain.device import InvalidDeviceId


class _StubPlayers:
    def __init__(self):
        self.rows: dict[str, PlayerRecord] = {}

    async def find_by_device_id(self, device_id):
        return self.rows.get(device_id)

    async def create(self, device_id):
        rec = PlayerRecord(id=len(self.rows) + 1, device_id=device_id, created_at=datetime.now(UTC))
        self.rows[device_id] = rec
        return rec


class _StubTokens:
    def issue(self, player_id):
        return f"token-for-{player_id}"


async def test_처음_보는_기기는_계정을_만들고_토큰을_낸다():
    players = _StubPlayers()
    r = await GuestInteractor(players=players, tokens=_StubTokens()).start(GuestCommand("dev-A"))
    assert r.created is True
    assert r.player_id == 1
    assert r.access_token == "token-for-1"


async def test_같은_기기는_같은_계정으로_다시_로그인한다():
    players = _StubPlayers()
    sut = GuestInteractor(players=players, tokens=_StubTokens())
    first = await sut.start(GuestCommand("dev-A"))
    again = await sut.start(GuestCommand("  dev-A  "))  # 공백은 정규화
    assert again.created is False
    assert again.player_id == first.player_id
    assert len(players.rows) == 1


async def test_기기_식별자가_비면_거부한다():
    with pytest.raises(InvalidDeviceId):
        await GuestInteractor(players=_StubPlayers(), tokens=_StubTokens()).start(GuestCommand("   "))
