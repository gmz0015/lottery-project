from fastapi import Header, HTTPException, status

from .config import settings


def _check_bearer(authorization: str | None) -> None:
    expected = f"Bearer {settings.api_token}"
    if authorization != expected:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="未授权")


def require_write(authorization: str | None = Header(default=None)) -> None:
    _check_bearer(authorization)


def require_read(authorization: str | None = Header(default=None)) -> None:
    if settings.read_requires_auth:
        _check_bearer(authorization)
