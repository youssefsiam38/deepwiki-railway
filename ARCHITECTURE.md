# Architecture

## The container

```
                          ┌──────────────────────── app (one container) ─────────────────────────┐
browser ──HTTPS/WSS──▶ Caddy :$PORT (public, basic auth)                                          │
                          │   ├─ /health                      ─▶ 127.0.0.1:8001  (no auth)          │
                          │   ├─ /ws/*  /codemap/*  (auth)     ─▶ 127.0.0.1:8001  (FastAPI backend)  │
                          │   └─ everything else    (auth)     ─▶ 127.0.0.1:3000  (Next.js app)      │
                          │                                          │ server-side rewrites/proxies  │
                          │                                          └─▶ 127.0.0.1:8001              │
                          └───────────────────────────────────────────────────────────────────────┘
                                                     volume: /root/.adalflow (repos + embeddings)
```

Three processes in one container, started by `images/app/entrypoint.sh`:

| Process | Port | Exposed | Role |
|---|---|---|---|
| Caddy | `$PORT` (Railway) | public | Basic-auth front-door and router |
| FastAPI (uvicorn) | 8001 | internal | The DeepWiki backend (RAG, generation, WebSockets) |
| Next.js (standalone) | 3000 | internal | The web UI, with server-side proxies/rewrites to the backend |

Railway injects `PORT` for the public port, which Caddy binds. The backend and the Next.js server are pinned to
fixed internal ports (8001, 3000) by the entrypoint, so Railway's `PORT` never collides with them (upstream's
API otherwise reads `PORT` itself and would try to bind Railway's public port).

## Request routing

The browser reaches the backend two ways:

1. **Through Next.js** — most calls. The UI calls same-origin paths like `/api/models/config`, `/api/wiki/*`,
   `/api/auth/*`, `/export/wiki/*`, `/local_repo/structure`. These hit Caddy → Next.js, and Next.js's route
   handlers and `next.config.ts` rewrites forward them to `127.0.0.1:8001` inside the container.
2. **Directly** — the WebSocket chat (`/ws/chat`), the codemap WebSocket (`/ws/codemap`), and the codemap file
   API (`/codemap/file`). These are opened by browser code against the page's own host, so Caddy routes `/ws/*`
   and `/codemap/*` straight to the backend. WebSocket upgrades pass through `reverse_proxy` transparently.

Basic auth covers both paths. Once the browser has authenticated to the origin (loading the UI), it attaches the
cached credentials to same-origin requests including WebSocket handshakes, so `/ws/*` is gated by the same
password as the UI without any separate token.

## The source patch

Upstream's browser code builds the WebSocket/API base URL in ways that break behind a reverse proxy:

- `src/utils/websocketClient.ts` used `wss://${window.location.hostname}:${NEXT_PUBLIC_API_PORT || 8001}` — the
  `:8001` points at a port the public domain does not expose.
- `src/app/[owner]/[repo]/slides/page.tsx` and `.../workshop/page.tsx` used
  `process.env.SERVER_BASE_URL || 'http://localhost:8001'` in **browser** code, where `SERVER_BASE_URL` is
  `undefined` (it is a server-only variable, not `NEXT_PUBLIC_*`), so they fell back to `localhost:8001` — the
  viewer's own machine. This is an upstream bug that breaks slides/workshop behind any reverse proxy.

`images/app/patch-source.mjs` rewrites all three to derive the base from `window.location.host` at runtime (each
file checked against its pinned-commit sha256 first). The result needs no build-time domain and works on any
host the container is served from.

## Image

`images/app/Dockerfile` builds upstream's pinned commit:

1. **fetch**: the exact commit, verified, with upstream's `package.json`/`package-lock.json` hash-checked.
2. **node_builder**: patch the source, install with the fixed frontend lockfile (`images/app/deps`), and
   `next build` (standalone output).
3. **py_deps**: `poetry install --only main` from upstream's `pyproject.toml`/`poetry.lock`, then upgrade
   `gitpython` to 3.1.62 (advisory fix).
4. **final**: Python 3.11 slim + Node 20 + the Caddy binary (copied from the official `caddy` image), the
   backend, the Next.js standalone build, the Caddyfile and the entrypoint.

## Start-up

`entrypoint.sh` (runs as root, matching upstream's image):

1. Requires `OWNER_PASSWORD` (≥8 chars) and hashes it with `caddy hash-password` (bcrypt) — the plaintext never
   reaches the Caddyfile or the process list.
2. Warns if no LLM key is set (the default embedder needs `OPENAI_API_KEY`).
3. Ensures `/root/.adalflow` and `api/logs` exist.
4. Starts the backend (`PORT=8001 python -m api.main`), the app (`PORT=3000 HOSTNAME=127.0.0.1 node server.js`),
   and Caddy (`$PORT`). If any exits, the container stops so Railway restarts it.
