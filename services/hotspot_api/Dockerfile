FROM python:3.12-slim-bookworm

COPY --from=ghcr.io/astral-sh/uv:0.10.11 /uv /uvx /bin/

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_NO_CACHE=1 \
    PATH="/app/.venv/bin:${PATH}" \
    PORT=8080

WORKDIR /app

RUN groupadd --system --gid 10001 subterrat \
    && useradd --system --uid 10001 --gid subterrat \
        --home-dir /nonexistent --shell /usr/sbin/nologin subterrat

COPY --chown=subterrat:subterrat pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY --chown=subterrat:subterrat services ./services

USER 10001:10001

EXPOSE 8080

CMD ["sh", "-c", "exec uvicorn services.hotspot_api.public_app:app --host 0.0.0.0 --port \"${PORT:-8080}\""]
