# Marketplace audit

Checked 2026-09-17.

| Question | Finding |
|---|---|
| Existing Railway templates | None for DeepWiki-Open (`_audit/gapscan.py`: "deepwiki", "deepwiki open"). |
| Demand | AsyncFuncAI/deepwiki-open: about 18,000 stars and 2,000 forks; 27 commits in the last 90 days (pinned commit 2026-09-03). |
| Licence | MIT (`LICENSE`). The repo remains MIT and self-hostable even though the author now also promotes a hosted "Grok Wiki". |
| Self-hostable | Yes: a Next.js UI + FastAPI backend, SQLite-free (file-based `.adalflow` store), with bring-your-own-key LLM/embedding providers (OpenAI, Google, OpenRouter, Ollama, OpenAI-compatible). |
| Why a template adds value | Upstream runs two open ports with the browser opening WebSockets straight to the API port, which does not work behind a single public domain and leaves an autonomous repo-cloning, LLM-spending service open to the internet. This template fronts it with a Caddy basic-auth gate and patches the browser to reach the API through the one domain. |
| Not included | Wiki generation itself (real repo + real LLM key) is outside the automated tests, which cover the front-door, authentication and routing. The default embedder needs an OpenAI key. Large repositories are memory-hungry (upstream suggests ~6 GB). |
