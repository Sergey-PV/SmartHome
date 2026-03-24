from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class APIModel(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)


class ErrorResponse(APIModel):
    code: str
    message: str
    details: dict[str, Any] | None = None


class HealthResponse(APIModel):
    status: str
    environment: str
    database: str | None = None


class CurrentDateResponse(APIModel):
    currentDate: datetime


class BiometricType(str, Enum):
    FACE_ID = "faceId"
    TOUCH_ID = "touchId"


class DeviceInfo(APIModel):
    deviceId: str
    platform: Literal["iOS"]
    appVersion: str | None = None
    osVersion: str | None = None
    deviceModel: str | None = None


class LoginRequest(APIModel):
    email: str
    password: str = Field(min_length=8)
    device: DeviceInfo


class RegisterRequest(APIModel):
    email: str
    password: str = Field(min_length=8)
    firstName: str | None = Field(default=None, max_length=120)
    lastName: str | None = Field(default=None, max_length=120)
    device: DeviceInfo


class RefreshTokenRequest(APIModel):
    refreshToken: str
    deviceId: str


class LogoutRequest(APIModel):
    refreshToken: str | None = None
    deviceId: str | None = None


class EnableBiometricRequest(APIModel):
    deviceId: str
    biometricType: BiometricType
    deviceName: str | None = Field(default=None, max_length=100)


class EnableBiometricResponse(APIModel):
    biometricEnabled: bool
    biometricToken: str
    issuedAt: datetime | None = None
    expiresAt: datetime | None = None


class BiometricLoginRequest(APIModel):
    biometricToken: str
    deviceId: str


class DisableBiometricRequest(APIModel):
    deviceId: str


class UserResponse(APIModel):
    id: str
    email: str
    firstName: str | None = None
    lastName: str | None = None
    emailVerified: bool
    createdAt: datetime | None = None


class AuthSessionResponse(APIModel):
    accessToken: str
    refreshToken: str
    tokenType: str
    expiresIn: int
    refreshExpiresIn: int | None = None
    user: UserResponse
    biometricAvailable: bool
    biometricEnabled: bool


class RefreshTokenResponse(APIModel):
    accessToken: str
    refreshToken: str
    tokenType: str
    expiresIn: int
    refreshExpiresIn: int | None = None


class SessionInfoResponse(APIModel):
    authenticated: bool
    user: UserResponse | None = None
    biometricEnabled: bool
    currentDeviceId: str | None = None
    sessionStartedAt: datetime | None = None
