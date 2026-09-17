# syntax=docker/dockerfile:1
#
# DeepWiki-Open for Railway: the Next.js UI and the FastAPI backend from a pinned upstream commit, behind a
# single Caddy front-door that adds HTTP basic authentication and routes the browser's direct API/WebSocket
# calls to the backend.
#
# Upstream runs the UI (:3000) and the API (:8001) as two ports with no authentication, and the browser opens
# WebSockets straight to the API port — which does not work behind a single-domain reverse proxy, and leaves the
# whole thing (repo cloning + your LLM keys) open to anyone who finds the URL. This image:
#   - patches the browser's WebSocket/API URLs to derive from the page's own host (patch-source.mjs; also fixes
#     an upstream bug that breaks the slides/workshop features behind ANY reverse proxy), so no build-time domain
#     is baked in;
#   - puts Caddy in front with basic auth over everything (except the health check), routing /ws/* and /codemap/*
#     to the API and the rest to Next.js;
#   - carries fixed frontend dependencies for published advisories (images/app/deps), and upgrades gitpython.
ARG GIT_IMAGE=docker.io/alpine/git:v2.49.1@sha256:c0280cf9572316299b08544065d3bf35db65043d5e3963982ec50647d2746e26
ARG NODE_IMAGE=docker.io/library/node:20.20.2-alpine3.22@sha256:8f47899606d000b0704e992f927fe7335adcd0d6c98851600072fb6e14a13e60
ARG PYTHON_IMAGE=docker.io/library/python:3.11.16-slim@sha256:9534e5a8e315485d4061ed659af0fd78a284c015f9b73661b41d6bab25604534
ARG CADDY_IMAGE=docker.io/library/caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d
ARG DEEPWIKI_COMMIT=d92819a9c9f3b99416e3580ff235fc9d3adf8b89
ARG UPSTREAM_PACKAGE_JSON_SHA256=352373d2ae3fa8b2db506665a16022601530cec4184246847994a1da32a114ae
ARG UPSTREAM_PACKAGE_LOCK_SHA256=001bebb6c5d6d80c0af2bd3d4c7c5503c868fd89839ee164bc28dce8494a6431

FROM ${CADDY_IMAGE} AS caddy_src

FROM ${GIT_IMAGE} AS fetch
ARG DEEPWIKI_COMMIT
ARG UPSTREAM_PACKAGE_JSON_SHA256
ARG UPSTREAM_PACKAGE_LOCK_SHA256
RUN git init -q /src \
    && git -C /src fetch -q --depth 1 https://github.com/AsyncFuncAI/deepwiki-open.git "${DEEPWIKI_COMMIT}" \
    && git -C /src checkout -q FETCH_HEAD \
    && test "$(git -C /src rev-parse HEAD)" = "${DEEPWIKI_COMMIT}" \
    && rm -rf /src/.git \
    && echo "${UPSTREAM_PACKAGE_JSON_SHA256}  /src/package.json" | sha256sum -c - \
    && echo "${UPSTREAM_PACKAGE_LOCK_SHA256}  /src/package-lock.json" | sha256sum -c -

# ---- Frontend ----
FROM ${NODE_IMAGE} AS node_builder
WORKDIR /app
COPY images/app/patch-source.mjs /tmp/patch-source.mjs
COPY --from=fetch /src/ /app-src/
RUN node /tmp/patch-source.mjs /app-src
# Fixed dependency manifests (published advisories) replace upstream's, then install.
COPY images/app/deps/package.json images/app/deps/package-lock.json ./
RUN npm ci --legacy-peer-deps
COPY --from=fetch /src/next.config.ts /src/tsconfig.json /src/tailwind.config.js /src/postcss.config.mjs ./
COPY --from=fetch /src/public ./public
RUN cp -r /app-src/src ./src
ENV NODE_OPTIONS="--max-old-space-size=4096" NEXT_TELEMETRY_DISABLED=1
RUN NODE_ENV=production npm run build

# ---- Backend deps ----
FROM ${PYTHON_IMAGE} AS py_deps
WORKDIR /api
COPY --from=fetch /src/api/pyproject.toml /src/api/poetry.lock ./
RUN python -m pip install poetry==2.0.1 --no-cache-dir \
    && poetry config virtualenvs.create true --local \
    && poetry config virtualenvs.in-project true --local \
    && poetry config virtualenvs.options.always-copy --local true \
    && POETRY_MAX_WORKERS=10 poetry install --no-interaction --no-ansi --only main \
    && poetry cache clear --all . \
    # Advisory fix: gitpython 3.1.58 -> 3.1.62 (deepwiki clones arbitrary Git repos). See UPSTREAM.md.
    # Verify by package metadata, not `import git` (this build stage has no git binary; the final stage does).
    && ./.venv/bin/pip install --no-cache-dir "gitpython==3.1.62" \
    && ./.venv/bin/python -c "import importlib.metadata as m; v = m.version('gitpython'); assert v == '3.1.62', v"

# ---- Final ----
FROM ${PYTHON_IMAGE}
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg git ca-certificates \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=caddy_src /usr/bin/caddy /usr/bin/caddy

ENV PATH="/opt/venv/bin:$PATH"
ENV TIKTOKEN_CACHE_DIR=/opt/tiktoken_cache/
COPY --from=py_deps /api/.venv /opt/venv
RUN mkdir -p "$TIKTOKEN_CACHE_DIR" && python -c "import tiktoken; tiktoken.get_encoding('cl100k_base')"

COPY --from=fetch /src/api/ ./api/
COPY --from=node_builder /app/public ./public
COPY --from=node_builder /app/.next/standalone ./
COPY --from=node_builder /app/.next/static ./.next/static

COPY images/app/Caddyfile /etc/caddy/Caddyfile
COPY --chmod=0755 images/app/entrypoint.sh /usr/local/bin/deepwiki-entrypoint
COPY licenses/ /usr/share/licenses/deepwiki-railway/

ARG DEEPWIKI_COMMIT
ARG WRAPPER_VERSION=0.0.0-dev
ARG VCS_REF=unknown
ARG BUILD_DATE=1970-01-01T00:00:00Z

ENV NODE_ENV=production \
    SERVER_BASE_URL=http://127.0.0.1:8001 \
    PYTHON_BACKEND_HOST=http://127.0.0.1:8001 \
    NEXT_TELEMETRY_DISABLED=1 \
    DEEPWIKI_AUTH_MODE=false \
    DEEPWIKI_COMMIT=${DEEPWIKI_COMMIT}

RUN test -s /app/server.js \
    && test -s /app/api/main.py \
    && caddy version \
    && caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>/dev/null || true \
    && bash -n /usr/local/bin/deepwiki-entrypoint \
    && ! grep -rqE "wsProtocol}//\\\$\{host\}:\\\$\{port\}" /app/.next 2>/dev/null || true

LABEL org.opencontainers.image.title="deepwiki-railway" \
      org.opencontainers.image.description="DeepWiki-Open for the Railway template: UI + API from a pinned commit behind a Caddy basic-auth front-door. Not affiliated with the DeepWiki-Open project." \
      org.opencontainers.image.source="https://github.com/youssefsiam38/deepwiki-railway" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${WRAPPER_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      io.deepwiki-railway.upstream.commit="${DEEPWIKI_COMMIT}"

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/deepwiki-entrypoint"]
