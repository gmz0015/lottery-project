from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from ..auth import require_read, require_write
from ..database import get_db
from ..models import Draw
from ..schemas import DrawIn, DrawOut, DrawList

router = APIRouter(prefix="/api/v1/draws", tags=["draws"])


def _get(db: Session, category: str, issue: str) -> Draw | None:
    return db.scalar(select(Draw).where(Draw.category == category, Draw.issue == issue))


@router.post("", response_model=DrawOut, dependencies=[Depends(require_write)])
def upsert_draw(body: DrawIn, db: Session = Depends(get_db)):
    row = _get(db, body.category, body.issue)
    if row is None:
        row = Draw(category=body.category, issue=body.issue)
        db.add(row)
    row.front_numbers = body.front_numbers
    row.back_numbers = body.back_numbers
    row.draw_date = body.draw_date
    row.prizes = body.prizes
    db.commit()
    db.refresh(row)
    return row


@router.get("/{category}/{issue}", response_model=DrawOut, dependencies=[Depends(require_read)])
def get_draw(category: str, issue: str, db: Session = Depends(get_db)):
    row = _get(db, category, issue)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="该期不存在")
    return row


@router.get("", response_model=DrawList, dependencies=[Depends(require_read)])
def list_draws(
    category: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=30, ge=1, le=200, alias="pageSize"),
    db: Session = Depends(get_db),
):
    stmt = select(Draw)
    count_stmt = select(func.count()).select_from(Draw)
    if category:
        stmt = stmt.where(Draw.category == category)
        count_stmt = count_stmt.where(Draw.category == category)
    total = db.scalar(count_stmt) or 0
    stmt = stmt.order_by(Draw.issue.desc()).offset((page - 1) * page_size).limit(page_size)
    items = list(db.scalars(stmt))
    return DrawList(items=items, total=total, page=page, page_size=page_size)


@router.delete("/{category}/{issue}", status_code=204, dependencies=[Depends(require_write)])
def delete_draw(category: str, issue: str, db: Session = Depends(get_db)):
    row = _get(db, category, issue)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="该期不存在")
    db.delete(row)
    db.commit()
    return Response(status_code=204)
