#!/usr/bin/env bash
# shellcheck disable=SC2015
# Live test of a deployed template: the flows the local smoke test covers that can be reached over HTTPS.
#
#   OWNER_PASSWORD_FILE=./owner-password tests/railway-smoke.sh https://<app-domain>
#
# Rerunnable: read-only. Secrets are read from files, never printed.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
[ $# -ge 1 ] || { sed -n '3,6p' "$0"; exit 2; }
APP_URL=${1%/}; export APP_URL
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

: "${OWNER_PASSWORD_FILE:?set OWNER_PASSWORD_FILE}"
tr -d '\n' < "$OWNER_PASSWORD_FILE" > "$TEST_TMP/pw"; chmod 600 "$TEST_TMP/pw"
printf '%s' "wrong-$(date +%s)" > "$TEST_TMP/wrong"

section "availability"
wait_for_code "$APP_URL/health" 200 300 && pass "health endpoint answers 200 over HTTPS without credentials" || die "not healthy"

section "basic auth gates everything"
assert_eq "the UI without credentials is 401" "401" "$(http_code "$APP_URL/")"
assert_eq "a wrong password is 401" "401" "$(auth_code "$TEST_TMP/wrong" "$APP_URL/")"
assert_eq "the UI with credentials is 200" "200" "$(auth_code "$TEST_TMP/pw" "$APP_URL/")"
body=$(curl -s --max-time 30 -u "owner:$(cat "$TEST_TMP/pw")" "$APP_URL/")
assert_contains "the UI is the DeepWiki app" 'DeepWiki\|__next\|_next/static' "$body"

section "browser-direct backend paths"
assert_eq "the chat WebSocket path without credentials is 401" "401" "$(http_code "$APP_URL/ws/chat")"
ws_authed=$(auth_code "$TEST_TMP/pw" "$APP_URL/ws/chat")
[ "$ws_authed" != "401" ] && pass "with credentials the WebSocket path reaches the backend ($ws_authed)" || fail "WS path still 401 with credentials"

section "the Next.js -> API proxy behind auth"
assert_eq "the models config API without credentials is 401" "401" "$(http_code "$APP_URL/api/models/config")"
cfg_code=$(auth_code "$TEST_TMP/pw" "$APP_URL/api/models/config")
[ "$cfg_code" = "200" ] && pass "the models config API with credentials is 200" || fail "models config API returned $cfg_code with credentials"

section "cookie / header hygiene"
# Basic auth is enforced by the edge over HTTPS; a bare request must not leak app content.
assert_not_contains "an unauthenticated response carries no app HTML" '_next/static' "$(curl -s --max-time 30 "$APP_URL/")"

summary
