#!/bin/bash
# DeepWiki-Open for Railway: start the FastAPI backend (:8001), the Next.js app (:3000), and the Caddy
# basic-auth front-door (Railway's $PORT). Secrets are never printed; only names and pass/fail.
set -euo pipefail

log() { printf '[deepwiki-railway] %s\n' "$*"; }
die() { printf '[deepwiki-railway] ERROR: %s\n' "$*" >&2; exit 1; }

# --- Basic-auth front door -------------------------------------------------------------------------------
[ -n "${OWNER_PASSWORD:-}" ] || die "OWNER_PASSWORD is not set. It is the dashboard's password (user: ${OWNER_USERNAME:-owner})."
[ "${#OWNER_PASSWORD}" -ge 8 ] || die "OWNER_PASSWORD is too short; use at least 8 characters."
# Hash the password with Caddy (bcrypt); the plaintext never reaches the Caddyfile or the process list.
CADDY_PASSWORD_HASH="$(caddy hash-password --plaintext "$OWNER_PASSWORD")"
export CADDY_PASSWORD_HASH
export OWNER_USERNAME="${OWNER_USERNAME:-owner}"

# --- LLM keys (deployer-supplied) ------------------------------------------------------------------------
if [ -z "${OPENAI_API_KEY:-}" ] && [ -z "${GOOGLE_API_KEY:-}" ] && [ -z "${OPENROUTER_API_KEY:-}" ]; then
  log "WARNING: no LLM provider key set (OPENAI_API_KEY / GOOGLE_API_KEY / OPENROUTER_API_KEY). The default"
  log "         embedder needs OPENAI_API_KEY; set at least one key and redeploy before generating a wiki."
fi

# The .adalflow data directory lives on the mounted volume (repo clones + embeddings).
export DEEPWIKI_CONFIG_DIR="${DEEPWIKI_CONFIG_DIR:-/root/.adalflow}"
mkdir -p /root/.adalflow /app/api/logs

log "deepwiki-open ${DEEPWIKI_COMMIT:-unknown}"

pids=()
# shellcheck disable=SC2317  # term() is reached via the trap below, not inline.
term() { log "shutting down"; for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; }
trap term TERM INT

# --- Backend (:8001, internal) ---------------------------------------------------------------------------
log "starting the API on :8001"
( cd /app && PORT=8001 exec python -m api.main ) &
pids+=($!)

# --- Frontend (:3000, internal) --------------------------------------------------------------------------
log "starting the web app on :3000"
( cd /app && PORT=3000 HOSTNAME=127.0.0.1 exec node server.js ) &
pids+=($!)

# --- Front door (Railway's $PORT, public) ----------------------------------------------------------------
log "starting the front door on :${PORT:-8080} (basic auth, user: ${OWNER_USERNAME})"
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
pids+=($!)

# If any of the three exits, bring the whole container down so Railway restarts it.
wait -n
die "a process exited; stopping the container"
