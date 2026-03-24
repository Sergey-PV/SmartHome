from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request, Response, status

from app.config import Settings, get_settings
from app.db import ping_database
from app.dependencies import get_auth_service, get_current_session, rate_limit_dependency
from app.models import AuthSession
from app.observability import metrics_endpoint
from app.schemas import (
    AuthSessionResponse,
    BiometricLoginRequest,
    CurrentDateResponse,
    DisableBiometricRequest,
    EnableBiometricRequest,
    EnableBiometricResponse,
    ErrorResponse,
    HealthResponse,
    LoginRequest,
    LogoutRequest,
    RegisterRequest,
    RefreshTokenRequest,
    RefreshTokenResponse,
    SessionInfoResponse,
    UserResponse,
)
from app.security import utc_now
from app.service import AuthService
router = APIRouter(prefix="/v1")


@router.post(
    "/auth/login",
    response_model=AuthSessionResponse,
    responses={400: {"model": ErrorResponse}, 401: {"model": ErrorResponse}, 423: {"model": ErrorResponse}},
)
async def login(
    payload: LoginRequest,
    _: Annotated[None, Depends(rate_limit_dependency("auth_login", "rate_limit_auth_per_minute"))],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> AuthSessionResponse:
    return await auth_service.login(payload)


@router.post(
    "/auth/register",
    status_code=status.HTTP_201_CREATED,
    response_model=AuthSessionResponse,
    responses={400: {"model": ErrorResponse}, 409: {"model": ErrorResponse}},
)
async def register(
    payload: RegisterRequest,
    _: Annotated[None, Depends(rate_limit_dependency("auth_register", "rate_limit_auth_per_minute"))],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> AuthSessionResponse:
    return await auth_service.register(payload)


@router.post(
    "/auth/refresh",
    response_model=RefreshTokenResponse,
    responses={401: {"model": ErrorResponse}},
)
async def refresh_token(
    payload: RefreshTokenRequest,
    _: Annotated[None, Depends(rate_limit_dependency("auth_refresh", "rate_limit_auth_per_minute"))],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> RefreshTokenResponse:
    return await auth_service.refresh(payload)


@router.post(
    "/auth/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={401: {"model": ErrorResponse}},
)
async def logout(
    current_session: Annotated[AuthSession, Depends(get_current_session)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
    payload: LogoutRequest | None = None,
) -> Response:
    await auth_service.logout(current_session, payload)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/auth/logout-all",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={401: {"model": ErrorResponse}},
)
async def logout_all(
    current_session: Annotated[AuthSession, Depends(get_current_session)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> Response:
    await auth_service.logout_all(current_session)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/auth/biometric/enable",
    response_model=EnableBiometricResponse,
    responses={401: {"model": ErrorResponse}, 409: {"model": ErrorResponse}},
)
async def enable_biometric(
    payload: EnableBiometricRequest,
    _: Annotated[None, Depends(rate_limit_dependency("biometric_enable", "rate_limit_biometric_per_minute"))],
    current_session: Annotated[AuthSession, Depends(get_current_session)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> EnableBiometricResponse:
    return await auth_service.enable_biometric(current_session, payload)


@router.post(
    "/auth/biometric/login",
    response_model=AuthSessionResponse,
    responses={401: {"model": ErrorResponse}, 403: {"model": ErrorResponse}},
)
async def login_with_biometric(
    payload: BiometricLoginRequest,
    _: Annotated[None, Depends(rate_limit_dependency("biometric_login", "rate_limit_biometric_per_minute"))],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> AuthSessionResponse:
    return await auth_service.login_with_biometric(payload)


@router.post(
    "/auth/biometric/disable",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={401: {"model": ErrorResponse}},
)
async def disable_biometric(
    payload: DisableBiometricRequest,
    current_session: Annotated[AuthSession, Depends(get_current_session)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> Response:
    await auth_service.disable_biometric(current_session, payload)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/auth/session",
    response_model=SessionInfoResponse,
    responses={401: {"model": ErrorResponse}},
)
async def get_session(
    current_session: Annotated[AuthSession, Depends(get_current_session)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> SessionInfoResponse:
    return await auth_service.get_session(current_session)


@router.get(
    "/users/me",
    response_model=UserResponse,
    responses={401: {"model": ErrorResponse}},
)
async def get_current_user(
    current_session: Annotated[AuthSession, Depends(get_current_session)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> UserResponse:
    return await auth_service.get_current_user(current_session)


@router.get("/health", response_model=HealthResponse)
async def health(settings: Annotated[Settings, Depends(get_settings)]) -> HealthResponse:
    return HealthResponse(status="ok", environment=settings.app_env)


@router.get("/health/ready", response_model=HealthResponse)
async def readiness(settings: Annotated[Settings, Depends(get_settings)]) -> HealthResponse:
    await ping_database()
    return HealthResponse(status="ok", environment=settings.app_env, database="up")


@router.get("/metrics", include_in_schema=False)
async def metrics(request: Request):
    settings = get_settings()
    if not settings.metrics_enabled:
        return Response(status_code=status.HTTP_404_NOT_FOUND)
    return await metrics_endpoint()


@router.get("/home/current-date", response_model=CurrentDateResponse)
async def current_date(
    _: Annotated[AuthSession, Depends(get_current_session)],
) -> CurrentDateResponse:
    return CurrentDateResponse(currentDate=utc_now())
