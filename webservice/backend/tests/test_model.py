import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import IntegrityError
from app.database import Base
from app.models import Draw


@pytest.fixture()
def session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    Local = sessionmaker(bind=engine)
    s = Local()
    yield s
    s.close()


def test_create_and_read_draw(session):
    d = Draw(category="ssq", issue="24001", front_numbers=[1, 2, 3, 4, 5, 6], back_numbers=[7])
    session.add(d)
    session.commit()
    got = session.scalar(select(Draw).where(Draw.category == "ssq", Draw.issue == "24001"))
    assert got.front_numbers == [1, 2, 3, 4, 5, 6]
    assert got.back_numbers == [7]
    assert got.prizes is None
    assert got.created_at is not None


def test_unique_category_issue(session):
    session.add(Draw(category="ssq", issue="24001", front_numbers=[1, 2, 3, 4, 5, 6], back_numbers=[7]))
    session.commit()
    session.add(Draw(category="ssq", issue="24001", front_numbers=[1, 2, 3, 4, 5, 7], back_numbers=[8]))
    with pytest.raises(IntegrityError):
        session.commit()
