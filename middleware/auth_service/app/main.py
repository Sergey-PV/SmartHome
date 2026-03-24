from __future__ import annotations

import json
import logging
import time
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.concurrency import iterate_in_threadpool

from app.config import get_settings
from app.db import ping_database, seed_user_if_configured
from app.logging_config import configure_logging
from app.observability import metrics_middleware
from app.rate_limit import RateLimiter, client_ip
from app.routes import router
from app.schemas import ErrorResponse
from app.service import AuthServiceError

logger = logging.getLogger(__name__)


def _truncate_text(value: str, max_length: int) -> str:
    if len(value) <= max_length:
        return value
    return value[:max_length] + "...<truncated>"


def _decode_body(body: bytes, max_length: int) -> str:
    if not body:
        return ""
    return _truncate_text(body.decode("utf-8", errors="replace"), max_length)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    configure_logging(settings.log_level)
    await ping_database()
    await seed_user_if_configured(settings)
    logger.info("auth service started", extra={"environment": settings.app_env})
    yield
    logger.info("auth service stopped")


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version="1.0.0",
        summary="Authentication middleware microservice for SmartHome",
        lifespan=lifespan,
    )

    app.state.rate_limiter = RateLimiter()

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allow_origins_list,
        allow_credentials=settings.cors_allow_credentials and settings.cors_allow_origins_list != ["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def global_rate_limit_middleware(request: Request, call_next):
        if settings.rate_limit_enabled and request.url.path not in {"/v1/health", "/v1/health/ready", "/v1/metrics"}:
            try:
                app.state.rate_limiter.check(
                    f"default:{client_ip(request)}",
                    limit=settings.rate_limit_default_per_minute,
                )
            except HTTPException as exc:
                detail = exc.detail if isinstance(exc.detail, dict) else {"code": "RATE_LIMITED", "message": str(exc.detail)}
                return JSONResponse(status_code=exc.status_code, content=detail)
        return await call_next(request)

    @app.middleware("http")
    async def request_context_middleware(request: Request, call_next):
        request_id = request.headers.get("x-request-id", str(uuid4()))
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response

    app.middleware("http")(metrics_middleware)

    @app.middleware("http")
    async def logging_middleware(request: Request, call_next):
        request_body = await request.body()

        async def receive():
            return {"type": "http.request", "body": request_body, "more_body": False}

        request._receive = receive  # type: ignore[attr-defined]
        started_at = time.perf_counter()
        response = await call_next(request)

        response_body = b""
        if settings.log_http_bodies:
            chunks = [chunk async for chunk in response.body_iterator]
            response_body = b"".join(chunks)
            response.body_iterator = iterate_in_threadpool(iter([response_body]))

        payload = {
            "request_id": getattr(request.state, "request_id", None),
            "method": request.method,
            "path": request.url.path,
            "query": request.url.query,
            "status_code": response.status_code,
            "duration_ms": round((time.perf_counter() - started_at) * 1000, 2),
        }

        if settings.log_http_headers:
            payload["request_headers"] = dict(request.headers)
            payload["response_headers"] = dict(response.headers)

        if settings.log_http_bodies:
            payload["request_body"] = _decode_body(request_body, settings.log_http_body_max_length)
            payload["response_body"] = _decode_body(response_body, settings.log_http_body_max_length)

        logger.info("http_exchange %s", json.dumps(payload, ensure_ascii=False, default=str))
        return response

    app.include_router(router)

    @app.exception_handler(AuthServiceError)
    async def auth_service_error_handler(_: Request, exc: AuthServiceError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=ErrorResponse(code=exc.code, message=exc.message, details=exc.details).model_dump(mode="json"),
        )

    @app.exception_handler(HTTPException)
    async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
        if isinstance(exc.detail, dict):
            payload = ErrorResponse(
                code=exc.detail.get("code", "HTTP_ERROR"),
                message=exc.detail.get("message", "Request failed"),
                details=exc.detail.get("details"),
            )
        else:
            payload = ErrorResponse(code="HTTP_ERROR", message=str(exc.detail))
        return JSONResponse(status_code=exc.status_code, content=payload.model_dump(mode="json"))

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
        payload = ErrorResponse(
            code="BAD_REQUEST",
            message="Request validation failed",
            details={"errors": exc.errors()},
        )
        return JSONResponse(status_code=422, content=payload.model_dump(mode="json"))

    @app.exception_handler(Exception)
    async def unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
        logger.exception(
            "unhandled_exception",
            extra={
                "path": request.url.path,
                "request_id": getattr(request.state, "request_id", None),
            },
        )
        return JSONResponse(
            status_code=500,
            content=ErrorResponse(code="INTERNAL_SERVER_ERROR", message="Unexpected server error").model_dump(mode="json"),
        )

    return app


app = create_app()
