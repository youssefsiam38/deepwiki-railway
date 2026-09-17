# Upstream

| Component | Pinned | Source |
|---|---|---|
| DeepWiki-Open | commit `d92819a9c9f3b99416e3580ff235fc9d3adf8b89` (2026-09-03) | https://github.com/AsyncFuncAI/deepwiki-open |
| Python base | `python:3.11.16-slim@sha256:9534e5a8e315485d4061ed659af0fd78a284c015f9b73661b41d6bab25604534` | Docker Hub official image |
| Node.js (frontend build) | `node:20.20.2-alpine3.22@sha256:8f47899606d000b0704e992f927fe7335adcd0d6c98851600072fb6e14a13e60` | Docker Hub official image |
| Caddy | `caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d` | Docker Hub official image (binary copied in) |
| Git (fetch stage) | `alpine/git:v2.49.1@sha256:c0280cf9572316299b08544065d3bf35db65043d5e3963982ec50647d2746e26` | Docker Hub |

DeepWiki-Open publishes a moving `ghcr.io/asyncfuncai/deepwiki-open:latest` image; this template builds a pinned
commit from source instead. The upstream README also promotes a hosted "Grok Wiki" (DeepWiki-Open 2.0), but the
repository remains MIT-licensed and self-hostable (Docker Compose and Dockerfiles present).

## Upstream files the build checks

| File | sha256 at the pinned commit |
|---|---|
| `package.json` | `352373d2ae3fa8b2db506665a16022601530cec4184246847994a1da32a114ae` |
| `package-lock.json` | `001bebb6c5d6d80c0af2bd3d4c7c5503c868fd89839ee164bc28dce8494a6431` |
| Each file `images/app/patch-source.mjs` changes | listed in its `EXPECTED` table |

## What this repository changes

See `ARCHITECTURE.md`. In short: browser WebSocket/API URLs are patched to use the page's own host (also fixing
an upstream reverse-proxy bug in the slides/workshop features), a Caddy basic-auth front-door is added, the
container's default command is replaced with a wrapper that starts all three processes, the frontend lockfile
carries advisory fixes, and `gitpython` is upgraded. The Python backend source is otherwise unmodified.

## Dependency fixes

### Frontend (`images/app/deps`)

Made from upstream's `package.json`/`package-lock.json` with `npm audit fix --package-lock-only --legacy-peer-deps`.

| Package | Upstream lockfile | Here |
|---|---|---|
| next | 15.5.x (critical + high advisories) | 15.5.25 |
| sharp | ≤0.35.4-rc.0 | 0.35.4 |
| nanoid | <3.3.18 | 3.3.19 |
| postcss | ≤8.5.22 | 8.5.23 |

`npm audit --omit=dev` afterwards: 0 critical, 1 high + 1 moderate, both a `postcss`/`next` chain fixable only by
Next.js 16 (a major upgrade from the 15.x line the app targets); pinned at the latest 15.x instead, matching the
non-breaking-fix policy.

### Backend (`pyproject.toml`/`poetry.lock`, one override)

`pip-audit` / OSV against upstream's lock at the pinned commit reports two packages:

| Package | Installed | Advisory | Action |
|---|---|---|---|
| gitpython | 3.1.58 | 5 GHSAs (incl. `--separate-git-dir` and TagReference bypasses), fixed in 3.1.59 | upgraded to 3.1.62 in the build |
| diskcache (transitive, via adalflow) | 5.6.3 | PYSEC-2026-2447 unsafe pickle deserialization | no fixed release exists (latest is 5.6.3); it deserializes its own local cache files, not attacker input — documented, not silenced |
