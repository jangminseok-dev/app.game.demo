from dataclasses import dataclass


@dataclass(frozen=True)
class RegistrarQuery:
    id: int
    name: str


@dataclass(frozen=True)
class RegistrarResponse:
    id: int
    name: str
    introduction: str
    access_token_ttl_seconds: int
