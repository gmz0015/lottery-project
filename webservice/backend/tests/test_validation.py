import pytest
from app.validation import validate_numbers


def test_ssq_valid():
    validate_numbers("ssq", [1, 2, 3, 4, 5, 6], [16])  # 不抛异常


def test_dlt_valid():
    validate_numbers("dlt", [1, 2, 3, 4, 35], [1, 12])


@pytest.mark.parametrize("front,back,kw", [
    ([1, 2, 3, 4, 5], [16], "6"),          # ssq 红球个数错
    ([1, 2, 3, 4, 5, 34], [16], "33"),     # ssq 红球越界
    ([1, 2, 3, 4, 5, 5], [16], "不"),       # ssq 红球重复
    ([1, 2, 3, 4, 5, 6], [17], "16"),      # ssq 蓝球越界
    ([1, 2, 3, 4, 5, 6], [1, 2], "1"),     # ssq 蓝球个数错
])
def test_ssq_invalid(front, back, kw):
    with pytest.raises(ValueError) as e:
        validate_numbers("ssq", front, back)
    assert kw in str(e.value)


def test_unknown_category():
    with pytest.raises(ValueError):
        validate_numbers("xxx", [1], [1])
