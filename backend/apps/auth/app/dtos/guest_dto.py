from dataclasses import dataclass


@dataclass(frozen=True)
class GuestCommand:
    device_id: str


@dataclass(frozen=True)
class GuestResponse:
    player_id: int
    access_token: str
    created: bool
