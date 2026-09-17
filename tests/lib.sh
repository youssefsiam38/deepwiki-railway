#!/usr/bin/env bash
# shellcheck disable=SC2015
# Shared helpers for deepwiki-railway tests. Source this file; do not execute it.
# Secrets are never echoed. Only names, counts, and pass/fail results are printed.

: "${APP_URL:=http://localhost:${DEEPWIKI_TEST_PORT:-13900}}"
: "${OWNER_USERNAME:=owner}"
: "${TEST_TIMEOUT:=300}"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
export TEST_TMP
_PASS=0; _FAIL=0

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -q -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }
assert_not_contains() { if grep -q -- "$2" <<<"$3"; then fail "$1: found forbidden [$2]"; else pass "$1"; fi; }

# curl still prints 000 through -w when it cannot connect, so `|| true`, never `|| echo 000`
http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$@" || true; }
# authenticated GET status
auth_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 -u "${OWNER_USERNAME}:$(cat "$1")" "${@:2}" || true; }

wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url")
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 3
  done
}

compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }

wait_for_log() {
  local svc=$1 pat=$2 min=${3:-1} timeout=${4:-$TEST_TIMEOUT} start n
  start=$(date +%s)
  while :; do
    n=$(compose logs --no-color --no-log-prefix "$svc" 2>/dev/null | grep -cE -- "$pat" || true)
    [ "$n" -ge "$min" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for [%s] in %s logs\n' "$pat" "$svc" >&2; return 1; fi
    sleep 2
  done
}

new_password() { (umask 077; openssl rand -hex 16 | tr -d '\n' > "$1"); }
