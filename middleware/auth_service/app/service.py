from __future__ import annotations

import logging
from datetime import timedelta
from uuid import uuid4

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError

from app.config import Settings
from app.models import AuthSession, BiometricDevice, User
from app.observability import record_auth_event
from app.schemas import (
    AuthSessionResponse,
    BiometricLoginRequest,
    DisableBiometricRequest,
    EnableBiometricRequest,
    EnableBiometricResponse,
    LoginRequest,
    LogoutRequest,
    RegisterRequest,
    RefreshTokenRequest,
    RefreshTokenResponse,
    SessionInfoResponse,
    UserResponse,
)
from app.security import generate_token, hash_password, hash_token, utc_now, verify_password

logger = logging.getLogger(__name__)


class AuthServiceError(Exception):
    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        details: dict | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details


class AuthService:
    def __init__(self, db_session: AsyncSession, settings: Settings) -> None:
        self.db_session = db_session
        self.settings = settings

    async def authenticate_access_token(self, access_token: str) -> AuthSession:
        now = utc_now()
        access_token_hash = self._hash_token(access_token)

        query = select(AuthSession).where(AuthSession.access_token_hash == access_token_hash)
        session = await self.db_session.scalar(query)
        if session is None:
            raise self.unauthorized_error()

        if session.revoked_at is not None:
            raise self.unauthorized_error()

        # An expired access token should not revoke the whole session, otherwise
        # the refresh token becomes unusable before its own TTL ends.
        if session.access_expires_at <= now:
            raise self.unauthorized_error()

        return session

    async def login(self, payload: LoginRequest) -> AuthSessionResponse:
        now = utc_now()
        email = payload.email.strip().lower()

        query = select(User).where(User.email == email)
        user = await self.db_session.scalar(query)
        if user is None:
            record_auth_event("login", "invalid_credentials")
            raise AuthServiceError(401, "INVALID_CREDENTIALS", "Email or password is incorrect")

        if user.locked_until and user.locked_until > now:
            record_auth_event("login", "locked")
            raise AuthServiceError(423, "ACCOUNT_LOCKED", "Account temporarily locked")

        if not verify_password(payload.password, user.password_hash):
            user.failed_attempts += 1
            if user.failed_attempts >= self.settings.max_failed_login_attempts:
                user.failed_attempts = 0
                user.locked_until = now + timedelta(seconds=self.settings.account_lock_ttl_seconds)
                await self.db_session.commit()
                record_auth_event("login", "locked")
                raise AuthServiceError(423, "ACCOUNT_LOCKED", "Account temporarily locked")

            await self.db_session.commit()
            record_auth_event("login", "invalid_credentials")
            raise AuthServiceError(401, "INVALID_CREDENTIALS", "Email or password is incorrect")

        user.failed_attempts = 0
        user.locked_until = None

        session, raw_tokens = await self._create_session(user_id=user.id, device_id=payload.device.deviceId)
        biometric_enabled = await self._has_active_biometric(user.id, payload.device.deviceId, now)
        await self.db_session.commit()

        record_auth_event("login", "success")
        return self._build_auth_session_response(
            session=session,
            user=user,
            biometric_enabled=biometric_enabled,
            access_token=raw_tokens["access_token"],
            refresh_token=raw_tokens["refresh_token"],
        )

    async def register(self, payload: RegisterRequest) -> AuthSessionResponse:
        email = payload.email.strip().lower()
        password = payload.password.strip()
        first_name = payload.firstName.strip() if payload.firstName else None
        last_name = payload.lastName.strip() if payload.lastName else None

        if not self._is_valid_email(email):
            raise AuthServiceError(400, "INVALID_EMAIL", "Email format is invalid")

        if len(password) < 8:
            raise AuthServiceError(400, "INVALID_PASSWORD", "Password must contain at least 8 characters")

        existing_user = await self.db_session.scalar(select(User).where(User.email == email))
        if existing_user is not None:
            record_auth_event("register", "already_exists")
            raise AuthServiceError(409, "EMAIL_ALREADY_REGISTERED", "User with this email already exists")

        now = utc_now()
        user = User(
            id=str(uuid4()),
            email=email,
            password_hash=hash_password(password),
            first_name=first_name or None,
            last_name=last_name or None,
            email_verified=True,
            created_at=now,
            failed_attempts=0,
            locked_until=None,
        )
        self.db_session.add(user)

        try:
            # Ensure the user row exists before creating a dependent auth session.
            await self.db_session.flush()
            session, raw_tokens = await self._create_session(user_id=user.id, device_id=payload.device.deviceId)
            await self.db_session.commit()
        except IntegrityError as error:
            await self.db_session.rollback()
            if self._is_duplicate_email_error(error):
                record_auth_event("register", "already_exists")
                raise AuthServiceError(409, "EMAIL_ALREADY_REGISTERED", "User with this email already exists")

            logger.exception("registration_commit_failed")
            record_auth_event("register", "failed")
            raise AuthServiceError(500, "REGISTRATION_FAILED", "Could not create user")

        record_auth_event("register", "success")
        return self._build_auth_session_response(
            session=session,
            user=user,
            biometric_enabled=False,
            access_token=raw_tokens["access_token"],
            refresh_token=raw_tokens["refresh_token"],
        )

    async def refresh(self, payload: RefreshTokenRequest) -> RefreshTokenResponse:
        now = utc_now()
        refresh_token_hash = self._hash_token(payload.refreshToken)

        query = select(AuthSession).where(AuthSession.refresh_token_hash == refresh_token_hash)
        session = await self.db_session.scalar(query)
        if session is None or session.revoked_at is not None:
            record_auth_event("refresh", "invalid")
            raise AuthServiceError(401, "INVALID_REFRESH_TOKEN", "Invalid or expired refresh token")

        if session.device_id != payload.deviceId or session.refresh_expires_at <= now:
            session.revoked_at = now
            await self.db_session.commit()
            record_auth_event("refresh", "invalid")
            raise AuthServiceError(401, "INVALID_REFRESH_TOKEN", "Invalid or expired refresh token")

        raw_tokens = self._rotate_session_tokens(session)
        await self.db_session.commit()

        record_auth_event("refresh", "success")
        return RefreshTokenResponse(
            accessToken=raw_tokens["access_token"],
            refreshToken=raw_tokens["refresh_token"],
            tokenType="Bearer",
            expiresIn=self.settings.access_token_ttl_seconds,
            refreshExpiresIn=self.settings.refresh_token_ttl_seconds,
        )

    async def logout(self, current_session: AuthSession, payload: LogoutRequest | None) -> None:
        if payload and payload.refreshToken:
            refresh_hash = self._hash_token(payload.refreshToken)
            if refresh_hash != current_session.refresh_token_hash:
                raise self.unauthorized_error()

        current_session.revoked_at = utc_now()
        await self.db_session.commit()
        record_auth_event("logout", "success")

    async def logout_all(self, current_session: AuthSession) -> None:
        await self.db_session.execute(
            update(AuthSession)
            .where(AuthSession.user_id == current_session.user_id, AuthSession.revoked_at.is_(None))
            .values(revoked_at=utc_now())
        )
        await self.db_session.commit()
        record_auth_event("logout_all", "success")

    async def enable_biometric(
        self,
        current_session: AuthSession,
        payload: EnableBiometricRequest,
    ) -> EnableBiometricResponse:
        now = utc_now()
        query = select(BiometricDevice).where(
            BiometricDevice.user_id == current_session.user_id,
            BiometricDevice.device_id == payload.deviceId,
        )
        existing = await self.db_session.scalar(query)
        if existing and existing.revoked_at is None and (existing.expires_at is None or existing.expires_at > now):
            record_auth_event("biometric_enable", "already_enabled")
            raise AuthServiceError(409, "BIOMETRIC_ALREADY_ENABLED", "Biometric auth already enabled for this device")

        raw_biometric_token = generate_token("bmt")
        record = existing or BiometricDevice(id=str(uuid4()), user_id=current_session.user_id, device_id=payload.deviceId)
        record.biometric_token_hash = self._hash_token(raw_biometric_token)
        record.biometric_type = payload.biometricType.value
        record.device_name = payload.deviceName
        record.issued_at = now
        record.expires_at = now + timedelta(seconds=self.settings.biometric_token_ttl_seconds)
        record.revoked_at = None

        self.db_session.add(record)
        await self.db_session.commit()
        record_auth_event("biometric_enable", "success")

        return EnableBiometricResponse(
            biometricEnabled=True,
            biometricToken=raw_biometric_token,
            issuedAt=record.issued_at,
            expiresAt=record.expires_at,
        )

    async def login_with_biometric(self, payload: BiometricLoginRequest) -> AuthSessionResponse:
        now = utc_now()
        token_hash = self._hash_token(payload.biometricToken)

        query = select(BiometricDevice).where(BiometricDevice.biometric_token_hash == token_hash)
        record = await self.db_session.scalar(query)
        if record is None or record.device_id != payload.deviceId:
            record_auth_event("biometric_login", "invalid")
            raise AuthServiceError(401, "INVALID_BIOMETRIC_TOKEN", "Invalid or expired biometric token")

        if record.revoked_at is not None:
            record_auth_event("biometric_login", "revoked")
            raise AuthServiceError(403, "BIOMETRIC_REVOKED", "Device is not trusted or biometric access revoked")

        if record.expires_at and record.expires_at <= now:
            record_auth_event("biometric_login", "expired")
            raise AuthServiceError(401, "INVALID_BIOMETRIC_TOKEN", "Invalid or expired biometric token")

        user = await self.db_session.get(User, record.user_id)
        if user is None:
            record_auth_event("biometric_login", "invalid")
            raise AuthServiceError(401, "INVALID_BIOMETRIC_TOKEN", "Invalid or expired biometric token")

        session, raw_tokens = await self._create_session(user_id=user.id, device_id=record.device_id)
        await self.db_session.commit()

        record_auth_event("biometric_login", "success")
        return self._build_auth_session_response(
            session=session,
            user=user,
            biometric_enabled=True,
            access_token=raw_tokens["access_token"],
            refresh_token=raw_tokens["refresh_token"],
        )

    async def disable_biometric(self, current_session: AuthSession, payload: DisableBiometricRequest) -> None:
        query = select(BiometricDevice).where(
            BiometricDevice.user_id == current_session.user_id,
            BiometricDevice.device_id == payload.deviceId,
        )
        record = await self.db_session.scalar(query)
        if record is not None:
            record.revoked_at = utc_now()
            await self.db_session.commit()
        record_auth_event("biometric_disable", "success")

    async def get_session(self, current_session: AuthSession) -> SessionInfoResponse:
        now = utc_now()
        user = await self.db_session.get(User, current_session.user_id)
        biometric_enabled = await self._has_active_biometric(current_session.user_id, current_session.device_id, now)

        return SessionInfoResponse(
            authenticated=True,
            user=self._to_user_response(user) if user else None,
            biometricEnabled=biometric_enabled,
            currentDeviceId=current_session.device_id,
            sessionStartedAt=current_session.started_at,
        )

    async def get_current_user(self, current_session: AuthSession) -> UserResponse:
        user = await self.db_session.get(User, current_session.user_id)
        if user is None:
            raise self.unauthorized_error()
        return self._to_user_response(user)

    async def _create_session(self, user_id: str, device_id: str) -> tuple[AuthSession, dict[str, str]]:
        now = utc_now()
        raw_access_token = generate_token("atk")
        raw_refresh_token = generate_token("rft")

        session = AuthSession(
            id=str(uuid4()),
            user_id=user_id,
            device_id=device_id,
            access_token_hash=self._hash_token(raw_access_token),
            refresh_token_hash=self._hash_token(raw_refresh_token),
            access_expires_at=now + timedelta(seconds=self.settings.access_token_ttl_seconds),
            refresh_expires_at=now + timedelta(seconds=self.settings.refresh_token_ttl_seconds),
            started_at=now,
            revoked_at=None,
        )
        self.db_session.add(session)

        return session, {
            "access_token": raw_access_token,
            "refresh_token": raw_refresh_token,
        }

    def _rotate_session_tokens(self, session: AuthSession) -> dict[str, str]:
        now = utc_now()
        raw_access_token = generate_token("atk")
        raw_refresh_token = generate_token("rft")

        session.access_token_hash = self._hash_token(raw_access_token)
        session.refresh_token_hash = self._hash_token(raw_refresh_token)
        session.access_expires_at = now + timedelta(seconds=self.settings.access_token_ttl_seconds)
        session.refresh_expires_at = now + timedelta(seconds=self.settings.refresh_token_ttl_seconds)

        return {
            "access_token": raw_access_token,
            "refresh_token": raw_refresh_token,
        }

    async def _has_active_biometric(self, user_id: str, device_id: str, now) -> bool:
        query = select(BiometricDevice).where(
            BiometricDevice.user_id == user_id,
            BiometricDevice.device_id == device_id,
            BiometricDevice.revoked_at.is_(None),
        )
        record = await self.db_session.scalar(query)
        if record is None:
            return False
        if record.expires_at and record.expires_at <= now:
            return False
        return True

    def _build_auth_session_response(
        self,
        session: AuthSession,
        user: User,
        biometric_enabled: bool,
        access_token: str,
        refresh_token: str,
    ) -> AuthSessionResponse:
        return AuthSessionResponse(
            accessToken=access_token,
            refreshToken=refresh_token,
            tokenType="Bearer",
            expiresIn=self.settings.access_token_ttl_seconds,
            refreshExpiresIn=self.settings.refresh_token_ttl_seconds,
            user=self._to_user_response(user),
            biometricAvailable=True,
            biometricEnabled=biometric_enabled,
        )

    def _to_user_response(self, user: User) -> UserResponse:
        return UserResponse(
            id=user.id,
            email=user.email,
            firstName=user.first_name,
            lastName=user.last_name,
            emailVerified=user.email_verified,
            createdAt=user.created_at,
        )

    def _hash_token(self, value: str) -> str:
        return hash_token(value, self.settings.token_hash_secret)

    def _is_valid_email(self, value: str) -> bool:
        return "@" in value and "." in value.rsplit("@", maxsplit=1)[-1]

    def _is_duplicate_email_error(self, error: IntegrityError) -> bool:
        original = getattr(error, "orig", None)
        message = str(original or error).lower()
        constraint_name = str(getattr(original, "constraint_name", "")).lower()

        duplicate_markers = (
            "ix_users_email",
            "users_email_key",
            "users.email",
            "duplicate key value violates unique constraint",
        )
        if constraint_name in {"ix_users_email", "users_email_key"}:
            return True
        return any(marker in message for marker in duplicate_markers)

    def unauthorized_error(self) -> AuthServiceError:
        return AuthServiceError(401, "UNAUTHORIZED", "Access token is missing or invalid")
