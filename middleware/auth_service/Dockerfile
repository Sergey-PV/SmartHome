FROM python:3.12-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY middleware/auth_service/ /app/

RUN pip install --upgrade pip \
    && pip install -e .
