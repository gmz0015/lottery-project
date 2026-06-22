from fastapi import APIRouter, HTTPException, status

from ..config import settings
from ..schemas import LoginIn, LoginOut

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/login", response_model=LoginOut)
def login(body: LoginIn):
    if body.password != settings.admin_password:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="密码错误")
    return LoginOut(token=settings.api_token)
