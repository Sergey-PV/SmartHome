from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from threading import RLock
from time import monotonic

from fastapi import HTTPException, Request, status


@dataclass(slots=True)
class RateLimiter:
    lock: RLock = field(default_factory=RLock)
    buckets: dict[str, deque[float]] = field(default_factory=dict)

    def check(self, key: str, limit: int, window_seconds: int = 60) -> None:
        now = monotonic()
        threshold = now - window_seconds

        with self.lock:
            bucket = self.buckets.setdefault(key, deque())
            while bucket and bucket[0] <= threshold:
                bucket.popleft()

            if len(bucket) >= limit:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail={
                        "code": "RATE_LIMITED",
                        "message": "Too many requests. Please try again later.",
                    },
                )

            bucket.append(now)


def client_ip(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host if request.client else "unknown"
