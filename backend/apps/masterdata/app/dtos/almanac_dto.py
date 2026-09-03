from dataclasses import dataclass


@dataclass(frozen=True)
class AlmanacQuery:
    id: int
    name: str


@dataclass(frozen=True)
class AlmanacResponse:
    """자기소개 + 현재 밸런스 버전. 클라이언트가 캐시 갱신 여부를 판단하는 값을 함께 싣는다."""

    id: int
    name: str
    introduction: str
    balance_version: int
