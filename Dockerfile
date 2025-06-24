# ------------------------------- Base Stage ------------------------------ #
FROM ghcr.io/astral-sh/uv:python3.13-alpine AS base

# Common environment variables
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0 \
    PATH="/root/.local/bin:${PATH}"

WORKDIR /app/

# Common dependency sync (without installing project)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project

# Copy source code (common for both environments)
COPY . /app/


# ------------------------------- Development Stage ------------------------------ #
FROM base AS dev

# Install all dependencies including dev
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked

# Create non-root user
RUN adduser -D appuser

ENV PATH="/app/.venv/bin:$PATH" \
    PORT=8000

USER appuser

WORKDIR /app/src/

EXPOSE 8000

# Run Uvicorn with reload for development
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]


# ------------------------------- Production Stage ------------------------------ #
FROM base AS prod-builder

# Install production dependencies only
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

FROM python:3.13-alpine AS prod

# Create non-root user
RUN adduser -D appuser

WORKDIR /app/

# Copy virtual environment and source code from builder
COPY --from=prod-builder /app/.venv .venv
COPY --from=prod-builder /app/src /app/src

# Set PATH to use virtual environment binaries
ENV PATH="/app/.venv/bin:$PATH" \
    PORT=8000

# Ensure proper permissions
RUN chown -R appuser:appuser /app

USER appuser

WORKDIR /app/src/

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
