from __future__ import annotations

from typing import Annotated

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.db import get_db_session
from app.models import AuthSession
from app.rate_limit import RateLimiter, client_ip
from app.service import AuthService

bearer_scheme = HTTPBearer(auto_error=False)


def get_rate_limiter(request: Request) -> RateLimiter:
    return request.app.state.rate_limiter


def get_auth_service(
    db_session: Annotated[AsyncSession, Depends(get_db_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AuthService:
    return AuthService(db_session=db_session, settings=settings)


async def get_current_session(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> AuthSession:
    if credentials is None:
        raise auth_service.unauthorized_error()
    return await auth_service.authenticate_access_token(credentials.credentials)


def _raise_from_rate_limit_detail(exc: HTTPException) -> None:
    detail = exc.detail if isinstance(exc.detail, dict) else {"code": "RATE_LIMITED", "message": str(exc.detail)}
    raise HTTPException(status_code=exc.status_code, detail=detail) from exc


def rate_limit_dependency(scope: str, limit_getter_name: str):
    async def dependency(
        request: Request,
        limiter: Annotated[RateLimiter, Depends(get_rate_limiter)],
        settings: Annotated[Settings, Depends(get_settings)],
    ) -> None:
        limit = getattr(settings, limit_getter_name)
        if not settings.rate_limit_enabled:
            return
        try:
            limiter.check(f"{scope}:{client_ip(request)}", limit=limit)
        except HTTPException as exc:
            _raise_from_rate_limit_detail(exc)

    return dependency
