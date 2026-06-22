from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, model_validator
from pydantic.alias_generators import to_camel

from .validation import validate_numbers


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class DrawIn(CamelModel):
    category: str
    issue: str
    front_numbers: list[int]
    back_numbers: list[int]
    draw_date: date | None = None
    prizes: dict[str, int] | None = None

    @model_validator(mode="after")
    def _check(self):
        validate_numbers(self.category, self.front_numbers, self.back_numbers)
        if self.prizes is not None:
            for k, v in self.prizes.items():
                if not isinstance(v, int) or v < 0:
                    raise ValueError(f"奖金 {k} 必须为非负整数")
        return self


class DrawOut(CamelModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, from_attributes=True)
    category: str
    issue: str
    front_numbers: list[int]
    back_numbers: list[int]
    draw_date: date | None = None
    prizes: dict[str, int] | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class DrawList(CamelModel):
    items: list[DrawOut]
    total: int
    page: int
    page_size: int


class LoginIn(CamelModel):
    password: str


class LoginOut(CamelModel):
    token: str
