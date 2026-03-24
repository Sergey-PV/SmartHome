from __future__ import annotations

from collections.abc import AsyncIterator
from functools import lru_cache
from uuid import uuid4

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

from app.config import Settings, get_settings
from app.models import User
from app.security import hash_password, utc_now


@lru_cache
def get_engine() -> AsyncEngine:
    settings = get_settings()
    return create_async_engine(settings.database_url, pool_pre_ping=True)


@lru_cache
def get_session_factory() -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(get_engine(), expire_on_commit=False)


async def get_db_session() -> AsyncIterator[AsyncSession]:
    session_factory = get_session_factory()
    async with session_factory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise


async def ping_database() -> None:
    async with get_engine().connect() as connection:
        await connection.execute(text("SELECT 1"))


async def seed_user_if_configured(settings: Settings) -> None:
    if not settings.seed_user_email or not settings.seed_user_password:
        return

    session_factory = get_session_factory()
    async with session_factory() as session:
        query = select(User).where(User.email == settings.seed_user_email.lower().strip())
        existing_user = await session.scalar(query)
        if existing_user is not None:
            return

        user = User(
            id=str(uuid4()),
            email=settings.seed_user_email.lower().strip(),
            password_hash=hash_password(settings.seed_user_password),
            first_name=settings.seed_user_first_name,
            last_name=settings.seed_user_last_name,
            email_verified=settings.seed_user_email_verified,
            created_at=utc_now(),
            failed_attempts=0,
            locked_until=None,
        )
        session.add(user)
        await session.commit()
