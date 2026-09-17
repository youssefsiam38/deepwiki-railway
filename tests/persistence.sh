#!/usr/bin/env bash
# shellcheck disable=SC2015
# Persistence: the .adalflow data lives on the volume. Write a marker file into it, take the stack down (keeping
# the volume), bring it back, and confirm the marker and the auth gate survived. Run after smoke.sh.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

printf '%s' local-test-only-owner-password > "$TEST_TMP/pw"

wait_for_code "$APP_URL/health" 200 60 || die "the stack is not running; run tests/smoke.sh first"

section "before"
marker="railway-persist-$(date +%s)"
compose exec -T app sh -c "echo '$marker' > /root/.adalflow/railway-persist-marker" || die "could not write the marker"
pass "wrote a marker into the .adalflow volume"

section "full restart"
compose down >/dev/null 2>&1
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_code "$APP_URL/health" 200 120 && pass "healthy again" || die "not healthy after the restart"

section "after"
got=$(compose exec -T app cat /root/.adalflow/railway-persist-marker 2>/dev/null | tr -d '\r\n')
assert_eq "the marker survived the restart" "$marker" "$got"
assert_eq "auth is still enforced" "401" "$(http_code "$APP_URL/")"
assert_eq "the same password still works" "200" "$(auth_code "$TEST_TMP/pw" "$APP_URL/")"

summary
