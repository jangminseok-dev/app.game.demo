"""게스트 계정의 기기 식별자 규칙 — 순수 파이썬."""

MAX_DEVICE_ID_LENGTH = 128


class InvalidDeviceId(ValueError):
    pass


def normalize_device_id(raw: str) -> str:
    """앞뒤 공백을 제거하고 길이·문자 범위를 검사한다. 위반이면 `InvalidDeviceId`."""
    value = raw.strip()
    if not value:
        raise InvalidDeviceId("기기 식별자가 비어 있습니다.")
    if len(value) > MAX_DEVICE_ID_LENGTH:
        raise InvalidDeviceId(f"기기 식별자가 너무 깁니다(최대 {MAX_DEVICE_ID_LENGTH}자).")
    if not value.isprintable() or any(ch.isspace() for ch in value):
        raise InvalidDeviceId("기기 식별자에 허용되지 않는 문자가 있습니다.")
    return value
