from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
from datetime import UTC, datetime


def utc_now() -> datetime:
    return datetime.now(tz=UTC)


def hash_password(password: str, salt: str | None = None) -> str:
    password_salt = salt or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        password_salt.encode("utf-8"),
        120_000,
    )
    encoded_digest = base64.urlsafe_b64encode(digest).decode("utf-8")
    return f"{password_salt}${encoded_digest}"


def verify_password(password: str, encoded_password: str) -> bool:
    salt, expected_digest = encoded_password.split("$", maxsplit=1)
    calculated = hash_password(password, salt=salt).split("$", maxsplit=1)[1]
    return secrets.compare_digest(calculated, expected_digest)


def generate_token(prefix: str) -> str:
    return f"{prefix}_{secrets.token_urlsafe(32)}"


def hash_token(token: str, secret: str) -> str:
    return hmac.new(secret.encode("utf-8"), token.encode("utf-8"), hashlib.sha256).hexdigest()
