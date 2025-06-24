## ------------------------------- Builder Stage ------------------------------ ##
FROM ghcr.io/astral-sh/uv:python3.13-alpine AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=0
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app/

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

COPY . /app/

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev


## ------------------------------- Production Stage ------------------------------ ##
FROM python:3.13-alpine

RUN adduser -D appuser
USER appuser

WORKDIR /app/
COPY --from=builder /app/.venv .venv
ENV PATH="/app/.venv/bin:$PATH"

WORKDIR /app/src/
COPY /src/ /app/src/

EXPOSE $PORT
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
