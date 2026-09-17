# DeepWiki-Open on Railway

A community Railway template for [DeepWiki-Open][upstream], the open-source tool that generates an interactive
wiki — architecture overview, per-component pages, Mermaid diagrams, a code-grounded "codemap" tour, and a chat
you can ask about the code — for any GitHub, GitLab or Bitbucket repository. It is not affiliated with the
DeepWiki-Open project.

Upstream runs the web UI and the API as two open ports, with the browser opening WebSockets straight to the API
port — which does not survive behind a single public domain, and leaves the whole thing (it clones repositories
and spends **your** LLM keys) reachable by anyone who finds the URL. This template runs it as **one service
behind a password**: a Caddy front-door adds HTTP basic authentication over everything and routes the browser's
API and WebSocket calls correctly, so a single Railway domain just works.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/deepwiki)

## What you get

- **One service, one volume** at `/root/.adalflow` (cloned repositories and their embeddings).
- **A password on the whole app.** A Caddy front-door requires HTTP basic auth (user `owner`, password
  `OWNER_PASSWORD`) for the UI, the API and the WebSockets alike — only the health check is open. Nothing is
  reachable without the password.
- **The browser talks to the API through the one domain.** Upstream bakes the API host into the browser bundle
  (and its slides/workshop features hard-code `localhost:8001`), so it breaks behind a reverse proxy. This
  template patches every browser WebSocket/API URL to use the page's own host, so `/ws/chat`, `/ws/codemap` and
  `/codemap/*` are routed to the backend by the front-door with no build-time domain baking.
- **Built from a pinned commit** with the frontend's published advisories fixed (Next.js, sharp, nanoid) and
  `gitpython` upgraded (it clones arbitrary repositories).
- **Bring your own LLM key** — OpenAI (also used for the default embedder), Google Gemini, OpenRouter, or an
  OpenAI-compatible endpoint. No model runs on Railway; the deployer's keys do the work.

## First run

1. Deploy the template. `OWNER_PASSWORD` is generated for you — copy it from the `app` service's **Variables**
   tab. The username is `owner`.
2. Set at least one LLM key on `app`: `OPENAI_API_KEY` (required for the default embeddings), and/or
   `GOOGLE_API_KEY` / `OPENROUTER_API_KEY`. Redeploy `app`.
3. Open the app's domain. The browser asks for the username/password (`owner` / `OWNER_PASSWORD`).
4. Enter a public repository URL (e.g. `https://github.com/AsyncFuncAI/deepwiki-open`) and let it generate. The
   first generation of a large repo takes a while and uses your LLM key.

## Variables you may want to change

All on the `app` service.

| Variable | Default | Meaning |
|---|---|---|
| `OWNER_PASSWORD` | generated | The basic-auth password for the whole app. Change it and redeploy to rotate. |
| `OWNER_USERNAME` | `owner` | The basic-auth username. |
| `OPENAI_API_KEY` | unset | OpenAI key. **Required** for the default embedder (and usable as a generator). |
| `GOOGLE_API_KEY` | unset | Google Gemini key (generator, and an alternative embedder). |
| `OPENROUTER_API_KEY` | unset | OpenRouter key (many models via one key). |
| `OPENAI_BASE_URL` | unset | An OpenAI-compatible endpoint instead of api.openai.com. |
| `OLLAMA_HOST` | unset | A reachable Ollama server, if you configure Ollama models. |
| `DEEPWIKI_EMBEDDER_TYPE` | `openai` | `google` or `ollama` to change the embedder (needs the matching key/host). |

`SERVER_BASE_URL`, `PYTHON_BACKEND_HOST`, `DEEPWIKI_AUTH_MODE`, `PORT`, `NODE_ENV` and the Caddy password hash
are fixed by this template; do not set them.

## Persistent data

| Service | Path | Holds | If lost |
|---|---|---|---|
| `app` | `/root/.adalflow` | Cloned repositories, generated wikis, and their embeddings | Generated wikis and caches (regenerated on demand) |

## Before you rely on it

- **It clones and reads whatever repository you point it at**, and sends code and questions to your configured
  LLM/embedding provider. Only point it at repositories you are comfortable sending to those providers.
- **Private repositories** need a token you supply in the UI; treat the instance as trusted (it is behind your
  password) before entering one.
- **Memory.** Generating a wiki for a large repository is memory-hungry; upstream suggests ~6 GB. Give the
  service enough memory on Railway, or start with smaller repositories.
- **Cost.** Every generation and chat spends your LLM key. There is no built-in spend cap.
- **Upstream direction.** The author now also offers a hosted "Grok Wiki"; this template builds the MIT
  open-source repository, which remains self-hostable.
- **Licence.** DeepWiki-Open is MIT.

## Local development

```bash
docker compose build
tests/static.sh
tests/smoke.sh
tests/persistence.sh
```

The compose file runs the one container with a fixed, local-test-only `OWNER_PASSWORD` and serves it on
`http://localhost:13900` (`DEEPWIKI_TEST_PORT` moves it). The local tests exercise the front-door, auth and
routing; they do not generate a wiki (that needs an LLM key).

After deploying:

```bash
OWNER_PASSWORD_FILE=./owner-password tests/railway-smoke.sh https://YOUR-DOMAIN
```

## Documents

| File | Contents |
|---|---|
| `ARCHITECTURE.md` | The container, the front-door, request routing, the source patch |
| `SECURITY.md` | Threat model, what is exposed, residual risks |
| `RAILWAY_TEMPLATE.md` | The exact template configuration |
| `UPSTREAM.md` | Pinned versions, digests, and what this repository changes |
| `MAINTENANCE.md` | Release process, bumping upstream, rollback |
| `MARKETPLACE_AUDIT.md` | Why this template exists |
| `THIRD_PARTY_NOTICES.md` | Licences |

## Licence

MIT for this repository's own files. DeepWiki-Open is MIT; see `THIRD_PARTY_NOTICES.md`.

[upstream]: https://github.com/AsyncFuncAI/deepwiki-open
