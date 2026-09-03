from dataclasses import dataclass


@dataclass(frozen=True)
class VaultQuery:
    id: int
    name: str


@dataclass(frozen=True)
class VaultResponse:
    id: int
    name: str
    introduction: str
    offline_cap_seconds: float
    offline_efficiency: float
