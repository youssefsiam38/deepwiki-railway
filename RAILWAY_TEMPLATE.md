# Railway template configuration

The template's exact configuration. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | DeepWiki-Open |
| Code | `deepwiki-open` |
| Template id | `e784c89c-f839-440a-a83c-7024b86417e5` |
| Deploy URL | https://railway.com/deploy/deepwiki-open |
| Category | AI/ML |
| Card description | AI-generated interactive wikis for any Git repo, behind a password |
| Icon | `assets/icon.png` |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |

Generated values use Railway's `secret()` function: `hexN` is `${{secret(N, "abcdef0123456789")}}` and `alnumN` is
`${{secret(N, "a-zA-Z0-9")}}` spelled out. Alphanumeric passwords are used wherever a value is embedded in a
connection URL, so nothing needs percent-encoding. Images are referenced by tag, because the template generator
rejects digests; `UPSTREAM.md` records the digests.

## Services

### `app`

| Field | Value |
|---|---|
| Source | `ghcr.io/youssefsiam38/deepwiki-railway:1.0.0` |
| Public domain | target port 8080 |
| Volume | `/root/.adalflow` |
| Healthcheck | `/health`, timeout from `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `OWNER_PASSWORD` | generated, alnum24 |
| `OWNER_USERNAME` | `owner` |
| `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `300` |
| `OPENAI_API_KEY` | optional, unset |
| `GOOGLE_API_KEY` | optional, unset |
| `OPENROUTER_API_KEY` | optional, unset |
| `OPENAI_BASE_URL` | optional, unset |
| `OLLAMA_HOST` | optional, unset |
| `DEEPWIKI_EMBEDDER_TYPE` | optional, unset |
