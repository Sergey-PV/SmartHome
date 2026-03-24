from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", case_sensitive=False)

    app_env: str = "development"
    app_name: str = "SmartHome Auth Middleware"
    host: str = "127.0.0.1"
    port: int = 8080
    log_level: str = "INFO"
    log_http_headers: bool = True
    log_http_bodies: bool = True
    log_http_body_max_length: int = 32768

    database_url: str = "postgresql+asyncpg://smarthome_auth:smarthome_auth@127.0.0.1:5432/smarthome_auth"
    token_hash_secret: str = Field(default="change-me", min_length=8)

    access_token_ttl_seconds: int = 900
    refresh_token_ttl_seconds: int = 2_592_000
    biometric_token_ttl_seconds: int = 15_552_000
    max_failed_login_attempts: int = 5
    account_lock_ttl_seconds: int = 300

    cors_allow_origins: str = "*"
    cors_allow_credentials: bool = True

    rate_limit_enabled: bool = True
    rate_limit_default_per_minute: int = 120
    rate_limit_auth_per_minute: int = 10
    rate_limit_biometric_per_minute: int = 15

    metrics_enabled: bool = True

    seed_user_email: str | None = None
    seed_user_password: str | None = None
    seed_user_first_name: str | None = None
    seed_user_last_name: str | None = None
    seed_user_email_verified: bool = True

    @property
    def cors_allow_origins_list(self) -> list[str]:
        if self.cors_allow_origins.strip() == "*":
            return ["*"]
        return [item.strip() for item in self.cors_allow_origins.split(",") if item.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
