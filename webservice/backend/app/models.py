from datetime import date, datetime

from sqlalchemy import String, JSON, Date, DateTime, Integer, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class Draw(Base):
    __tablename__ = "draws"
    __table_args__ = (UniqueConstraint("category", "issue", name="uq_category_issue"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    category: Mapped[str] = mapped_column(String(8), index=True)
    issue: Mapped[str] = mapped_column(String(16), index=True)
    front_numbers: Mapped[list] = mapped_column(JSON)
    back_numbers: Mapped[list] = mapped_column(JSON)
    draw_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    prizes: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )
