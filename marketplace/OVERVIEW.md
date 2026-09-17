# Deploy and Host DeepWiki-Open on Railway

DeepWiki-Open turns any GitHub, GitLab or Bitbucket repository into an interactive wiki: an architecture
overview, per-component pages, Mermaid diagrams, a code-grounded guided "codemap" tour, and a chat you can ask
about the code. This is a community-maintained template; it is not affiliated with the DeepWiki-Open project.

## About Hosting DeepWiki-Open

DeepWiki-Open is a Next.js web UI plus a FastAPI backend that clones a repository, embeds it, and generates
documentation with your chosen LLM. Upstream runs the UI and API as two separate open ports, with the browser
opening WebSockets straight to the API port — a setup that does not work behind a single public domain and
leaves an autonomous, repository-cloning, LLM-spending service reachable by anyone who finds the URL.

This template runs it as one Railway service behind a password. A Caddy front-door adds HTTP basic
authentication over the UI, the API and the WebSockets, and routes the browser's API and WebSocket calls to the
backend on the same domain — the browser code is patched to reach the API through the page's own host, so no
build-time domain is baked in. Bring your own LLM key; everything else works out of the box.

## Common Use Cases

- A private, always-current wiki for your own repositories, behind a password.
- Onboarding documentation and architecture diagrams generated on demand for any repo.
- A code-aware chat and guided codemap over a large codebase.

## Dependencies for DeepWiki-Open Hosting

- At least one LLM provider key: OpenAI (also the default embedder), Google Gemini, OpenRouter, or an
  OpenAI-compatible endpoint.
- Enough memory for the repositories you generate wikis for (upstream suggests around 6 GB for large ones).

### Deployment Dependencies

- DeepWiki-Open: https://github.com/AsyncFuncAI/deepwiki-open (MIT)
- Caddy: https://caddyserver.com (Apache-2.0)
- Template repository, image and tests: https://github.com/youssefsiam38/deepwiki-railway

### Implementation Details

The image is built from a pinned upstream commit. The browser's WebSocket and API URLs are patched to derive
from the page's own host (also fixing an upstream bug that breaks the slides/workshop features behind any
reverse proxy). A Caddy front-door requires HTTP basic authentication for everything except the health check,
routing the WebSocket and codemap paths to the backend and the rest to the Next.js app. The frontend's published
advisories (Next.js, sharp, nanoid) are fixed and gitpython is upgraded, since the app clones arbitrary
repositories.

Tested in CI and on a live deployment of this template: the front-door starts, authentication gates the UI, API
and WebSocket paths, the Next.js-to-API proxy works behind the gate, and a redeploy keeps the volume.

The deploy form generates `OWNER_PASSWORD` (username `owner`). Copy it from the app service's variables, add an
LLM key, and sign in on the app's domain.

## Why Deploy DeepWiki-Open on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your
infrastructure so you don't have to deal with configuration, while allowing you to vertically and
horizontally scale it.

By deploying DeepWiki-Open on Railway, you are one step closer to supporting a complete full-stack application
with minimal burden. Host your servers, databases, AI agents, and more on Railway.
