#!/usr/bin/env bash
# shellcheck disable=SC2015
# End-to-end smoke test of the local compose stack: the front-door starts, basic auth gates everything except
# the health check, the UI and the Next.js->API proxy work with credentials, and the browser-direct API/WS
# paths are gated too. Destroys and recreates the test stack's volume.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

printf '%s' local-test-only-owner-password > "$TEST_TMP/pw"
WRONG="$TEST_TMP/wrong"; printf '%s' nope-wrong-password > "$WRONG"

section "start-up"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_code "$APP_URL/health" 200 180 || { compose logs --tail 100 app >&2; die "front door never became healthy"; }
pass "health endpoint answers 200 without credentials"
wait_for_log app 'starting the front door' 1 30 && pass "entrypoint started the front door" || fail "no front-door log line"
logs=$(compose logs --no-color app 2>/dev/null)
assert_not_contains "logs never show the password" 'local-test-only-owner-password' "$logs"
assert_contains "the entrypoint hashes the password" 'starting the front door' "$logs"

section "basic auth gates everything"
assert_eq "the UI without credentials is 401" "401" "$(http_code "$APP_URL/")"
assert_eq "a wrong password is 401" "401" "$(auth_code "$WRONG" "$APP_URL/")"
assert_eq "the UI with credentials is 200" "200" "$(auth_code "$TEST_TMP/pw" "$APP_URL/")"
body=$(curl -s --max-time 30 -u "owner:$(cat "$TEST_TMP/pw")" "$APP_URL/")
assert_contains "the UI is the DeepWiki app" 'DeepWiki\|__next\|_next/static' "$body"

section "browser-direct backend paths are gated and routed"
# /ws/* and /codemap/* go straight to the API through Caddy. Without creds Caddy blocks them (401).
assert_eq "the chat WebSocket path without credentials is 401" "401" "$(http_code "$APP_URL/ws/chat")"
assert_eq "the codemap path without credentials is 401" "401" "$(http_code "$APP_URL/codemap/file")"
# With creds, Caddy forwards to the backend. A plain GET on a WebSocket route is not a 401 (the backend answers).
ws_authed=$(auth_code "$TEST_TMP/pw" "$APP_URL/ws/chat")
[ "$ws_authed" != "401" ] && pass "with credentials the WebSocket path reaches the backend ($ws_authed)" || fail "WS path still 401 with credentials"

section "the Next.js -> API proxy works behind auth"
# /api/models/config is served by Next and reaches the backend internally.
cfg_code=$(auth_code "$TEST_TMP/pw" "$APP_URL/api/models/config")
assert_eq "the models config API without credentials is 401" "401" "$(http_code "$APP_URL/api/models/config")"
[ "$cfg_code" = "200" ] && pass "the models config API with credentials is 200" || fail "models config API returned $cfg_code with credentials"
cfg_body=$(curl -s --max-time 30 -u "owner:$(cat "$TEST_TMP/pw")" "$APP_URL/api/models/config")
assert_contains "the models config comes from the backend" 'providers\|supportedProviders\|embedder\|default' "$cfg_body"

section "health routing"
# /health reaches the backend's health endpoint (not the Next app).
h=$(curl -s --max-time 30 "$APP_URL/health")
assert_contains "the health body is the backend's" 'status\|healthy\|ok\|message' "$h"

section "restart survives"
compose restart app >/dev/null 2>&1 || true
wait_for_code "$APP_URL/health" 200 120 && pass "healthy again after a restart" || fail "not healthy after a restart"
assert_eq "auth is still enforced" "401" "$(http_code "$APP_URL/")"
assert_eq "the same password still works" "200" "$(auth_code "$TEST_TMP/pw" "$APP_URL/")"

summary
