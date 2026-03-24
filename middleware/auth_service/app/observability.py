from __future__ import annotations

from time import perf_counter

from fastapi import Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest


REQUEST_COUNT = Counter(
    "smarthome_auth_http_requests_total",
    "Total number of HTTP requests",
    ["method", "path", "status_code"],
)
REQUEST_LATENCY = Histogram(
    "smarthome_auth_http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "path"],
)
AUTH_EVENTS = Counter(
    "smarthome_auth_events_total",
    "Auth domain events",
    ["event", "result"],
)


def record_auth_event(event: str, result: str) -> None:
    AUTH_EVENTS.labels(event=event, result=result).inc()


async def metrics_endpoint() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


async def metrics_middleware(request: Request, call_next):
    start = perf_counter()
    response = await call_next(request)
    elapsed = perf_counter() - start

    path = request.url.path
    method = request.method
    status_code = str(response.status_code)

    REQUEST_COUNT.labels(method=method, path=path, status_code=status_code).inc()
    REQUEST_LATENCY.labels(method=method, path=path).observe(elapsed)

    return response
