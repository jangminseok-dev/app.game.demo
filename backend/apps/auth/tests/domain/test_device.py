import pytest

from auth.domain.device import InvalidDeviceId, normalize_device_id


def test_정상_식별자는_공백만_제거된다():
    assert normalize_device_id(" abc-123_XYZ ") == "abc-123_XYZ"


@pytest.mark.parametrize("bad", ["", "   ", "a b", "x" * 129, "tab\tid", "nl\nid"])
def test_비었거나_공백_포함이거나_너무_길면_거부(bad):
    with pytest.raises(InvalidDeviceId):
        normalize_device_id(bad)
