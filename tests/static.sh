#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
# Static validation: syntax, shellcheck, compose, pins, the source patch and the security defaults. No Docker build.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
cd "$REPO_ROOT"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

section "syntax"
for f in images/app/*.sh tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "parses: $f"; else fail "syntax error: $f"; fi
done
if node --check images/app/patch-source.mjs 2>/dev/null; then pass "parses: patch-source.mjs"; else fail "syntax error: patch-source.mjs"; fi

section "shellcheck"
if command -v shellcheck >/dev/null; then
  if shellcheck -x -s bash images/app/entrypoint.sh; then pass "shellcheck entrypoint"; else fail "shellcheck entrypoint"; fi
  if shellcheck -x -s bash tests/*.sh; then pass "shellcheck tests"; else fail "shellcheck tests"; fi
else
  echo "  SKIP  shellcheck not installed"
fi

section "compose"
if docker compose -f compose.yaml config -q; then pass "compose config"; else fail "compose config"; fi
cfg=$(docker compose -f compose.yaml config --format json)
assert_eq "one service" "app" "$(jq -r '[.services | keys[]] | join(" ")' <<<"$cfg")"
assert_eq "the port binds to loopback" "127.0.0.1" "$(jq -r '[.services.app.ports[]? | .host_ip] | join(" ")' <<<"$cfg")"
assert_eq "one volume, at /root/.adalflow" "/root/.adalflow" "$(jq -r '[.services.app.volumes[]? | .target] | join(" ")' <<<"$cfg")"

section "image pins"
df=images/app/Dockerfile
for arg in GIT_IMAGE NODE_IMAGE PYTHON_IMAGE CADDY_IMAGE; do
  assert_contains "$arg pinned by digest" "^ARG $arg=.*@sha256:[0-9a-f]\{64\}$" "$(grep "^ARG $arg=" "$df")"
done
assert_contains "an exact upstream commit" '^ARG DEEPWIKI_COMMIT=[0-9a-f]\{40\}$' "$(grep '^ARG DEEPWIKI_COMMIT=' "$df")"
assert_contains "the build verifies the fetched commit" 'test "$(git -C /src rev-parse HEAD)" = "${DEEPWIKI_COMMIT}"' "$(cat "$df")"
assert_contains "the build checks upstream's frontend manifests" 'UPSTREAM_PACKAGE_LOCK_SHA256}  /src/package-lock.json' "$(cat "$df")"
assert_contains "gitpython is upgraded for the advisory" 'gitpython==3.1.62' "$(cat "$df")"

section "dependency fixes"
deps=images/app/deps
assert_eq "lockfile belongs to the manifest" "$(jq -r '.name' "$deps/package.json")" "$(jq -r '.name' "$deps/package-lock.json")"
ver() { jq -r --arg p "node_modules/$1" '.packages[$p].version' "$deps/package-lock.json"; }
gte() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }
gte "$(ver next)" 15.5.25 && pass "next fixed ($(ver next))" || fail "next below 15.5.25"
gte "$(ver sharp)" 0.35.4 && pass "sharp fixed ($(ver sharp))" || fail "sharp below 0.35.4"
gte "$(ver nanoid)" 3.3.18 && pass "nanoid fixed ($(ver nanoid))" || fail "nanoid below 3.3.18"

section "source patch"
p=images/app/patch-source.mjs
assert_eq "every patched file is hash-checked" "3" "$(grep -cE '^  "[^"]+": "[0-9a-f]{64}",$' "$p")"
assert_contains "websocket base uses the page host" 'wsProtocol}//${window.location.host}' "$(cat "$p")"
assert_contains "slides/workshop broken block is replaced" 'window.location.host}` : (process.env.SERVER_BASE_URL' "$(cat "$p")"

section "front-door security"
cf=images/app/Caddyfile
assert_contains "basic auth is configured" 'basic_auth {' "$(cat "$cf")"
assert_contains "the health check is exempt from auth" 'handle /health {' "$(cat "$cf")"
assert_contains "/ws and /codemap route to the backend" '@backend path /ws/\* /codemap/\*' "$(cat "$cf")"
e=images/app/entrypoint.sh
assert_contains "refuses to start without OWNER_PASSWORD" 'OWNER_PASSWORD is not set' "$(cat "$e")"
assert_contains "refuses a short OWNER_PASSWORD" 'too short' "$(cat "$e")"
assert_contains "the password is hashed, not stored plaintext" 'caddy hash-password --plaintext' "$(cat "$e")"
assert_contains "the API runs on the internal port, not Railway's PORT" 'PORT=8001 exec python -m api.main' "$(cat "$e")"
assert_contains "the app runs on the internal port" 'PORT=3000 HOSTNAME=127.0.0.1 exec node server.js' "$(cat "$e")"
leaks=$(grep -nE "printf '\[deepwiki-railway\].*OWNER_PASSWORD" "$e" | grep -v 'is not set\|too short\|#{OWNER_PASSWORD}' || true)
assert_eq "no log line prints the password" "" "$leaks"
assert_contains "upstream auth mode is off (Caddy handles auth)" 'DEEPWIKI_AUTH_MODE=false' "$(cat "$df")"

section "secrets hygiene"
mapfile -t tracked < <(git ls-files 2>/dev/null | grep . || find . -type f -not -path './.git/*' -not -path './test-output/*')
if [ "${#tracked[@]}" -gt 0 ] && grep -lE '(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "${tracked[@]}" 2>/dev/null; then
  fail "a credential-shaped string is in the repository"
else
  pass "no credential-shaped strings in ${#tracked[@]} files"
fi

summary
