# Security

## What is exposed

| Surface | Who can reach it | Protection |
|---|---|---|
| The UI, the API, and the WebSockets (`app`'s domain) | anyone with the password | Caddy HTTP basic auth (user `owner`, password `OWNER_PASSWORD`), bcrypt-hashed at start-up; enforced at the edge before any request reaches the UI or backend |
| `/health` | anyone | Deliberately open (Railway's health check), forwarded to the backend's health endpoint — returns status only |
| The backend (`:8001`), the Next.js server (`:3000`) | inside the container only | No public port; only Caddy reverse-proxies to them |
| The `/root/.adalflow` volume | the container | Cloned repos and embeddings |

## Defaults this template changes

- **A password on everything.** Upstream ships the UI and API with no authentication (`DEEPWIKI_AUTH_MODE`
  defaults off, and even when on it only gates wiki generation, not chat/codemap/reading). This template puts
  every path behind basic auth at the edge, so an autonomous code-cloning, LLM-spending service is not left open
  to the internet.
- **The browser reaches the API through the one public domain.** Upstream's browser code targets `:8001`
  directly (and the slides/workshop features hard-code `localhost:8001`), which does not work behind a single
  domain. Patched to use the page's own host (`ARCHITECTURE.md`).
- **Dependency advisories.** The frontend lockfile at the pinned commit has 1 critical + 3 high advisories;
  `images/app/deps` resolves them (Next.js 15.5.25, sharp 0.35.4, nanoid 3.3.19, postcss 8.5.23).
  `gitpython` is upgraded 3.1.58 → 3.1.62 (it clones arbitrary Git repos). See `UPSTREAM.md`.

## Residual risks

- **It clones and reads arbitrary repositories** and sends their code and your questions to your configured
  LLM/embedding providers. Only point it at repositories you are comfortable sending to those providers, and
  keep the instance behind its password.
- **One shared password, one role.** Anyone with the password has full control, including changing which
  providers and keys are configured. There are no per-user accounts.
- **Basic auth over WebSocket** relies on the browser attaching the cached origin credentials to the same-origin
  WebSocket handshake (standard behaviour in current Chrome/Firefox/Safari once the page has loaded with auth).
  A client that does not do this would fail to open the chat, not bypass the gate.
- **Private-repository tokens** entered in the UI are sent to the backend and used to clone; treat the instance
  as trusted before entering one.
- **`diskcache` unsafe-pickle advisory** (PYSEC-2026-2447) has no fixed release; it is a transitive dependency
  (via `adalflow`) that deserializes its own local cache files, not attacker-controlled input. Documented in
  `UPSTREAM.md`.
- **Cost / abuse.** There is no built-in spend cap; anyone with the password can run generations that spend your
  LLM key.

## Reporting

Report problems with this template in the repository's issues without secrets or personal data. Report
vulnerabilities in DeepWiki-Open itself to the upstream project.
