# Auth Middleware Microservice

Python middleware microservice for SmartHome authentication.

## Stack

- FastAPI
- Uvicorn
- PostgreSQL
- SQLAlchemy Async
- Alembic
- Prometheus metrics

## Features

- Email/password registration
- Email/password login
- Access token and refresh token rotation
- Logout current session
- Logout all sessions
- Biometric enable / disable
- Biometric session restore
- Current session inspection
- Current user profile endpoint
- CORS
- In-memory rate limiting
- Request logging
- `/metrics`, `/v1/health`, `/v1/health/ready`

## Environment

Copy `.env.example` to `.env` and fill at least:

- `DATABASE_URL`
- `TOKEN_HASH_SECRET`
- optional seed user vars

## Database

```bash
createdb smarthome_auth
```

Run migrations:

```bash
cd middleware/auth_service
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
alembic upgrade head
```

## Run

```bash
uvicorn app.main:app --host 127.0.0.1 --port 8080
```

Service base URL:

- `http://127.0.0.1:8080/v1`

## Notes

- Passwords are hashed with PBKDF2 from Python stdlib.
- Tokens are opaque secure tokens generated with `secrets`, while DB stores only token hashes.
- Rate limiting is currently in-memory. For multi-instance production, move limiter state to Redis.
