import pytest
from pydantic import ValidationError
from app.schemas import DrawIn, DrawOut


def test_drawin_camel_and_validation():
    d = DrawIn.model_validate({
        "category": "ssq", "issue": "24001",
        "frontNumbers": [1, 2, 3, 4, 5, 6], "backNumbers": [16],
    })
    assert d.front_numbers == [1, 2, 3, 4, 5, 6]
    assert d.prizes is None


def test_drawin_rejects_bad_numbers():
    with pytest.raises(ValidationError):
        DrawIn.model_validate({
            "category": "ssq", "issue": "24001",
            "frontNumbers": [1, 2, 3], "backNumbers": [16],
        })


def test_drawout_serializes_camel():
    class FakeRow:
        category = "dlt"; issue = "24001"
        front_numbers = [1, 2, 3, 4, 5]; back_numbers = [1, 2]
        draw_date = None; prizes = None
        created_at = None; updated_at = None
    out = DrawOut.model_validate(FakeRow())
    body = out.model_dump(by_alias=True)
    assert body["frontNumbers"] == [1, 2, 3, 4, 5]
    assert "backNumbers" in body and "createdAt" in body
