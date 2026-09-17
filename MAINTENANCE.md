# Maintenance

## Release process

1. Make the change on a branch. The `test` workflow builds the image and runs the full suite on every push and
   pull request.
2. Run locally:
   ```bash
   docker compose build --pull
   tests/static.sh && tests/smoke.sh && tests/persistence.sh
   ```
3. Tag `vX.Y.Z`. The `publish-image` workflow builds the image as a local candidate, runs the smoke and
   persistence suites against it, and only then retags and pushes that exact image to GHCR as `X.Y.Z`, `X.Y`
   and `latest`.
4. Update the Railway template (id in `RAILWAY_TEMPLATE.md`): the `app` image tag, with
   `templateChangeSetStage` then `templateChangeSetApply`. Tags only. Republish the overview with
   `railway templates update <id> --readme-file marketplace/OVERVIEW.md` if it changed. Never put
   angle-bracket placeholders in the overview or variable descriptions: Railway strips them.
5. Deploy the updated template into a scratch project with an LLM key, run
   ```bash
   OWNER_PASSWORD_FILE=... tests/railway-smoke.sh https://APP-DOMAIN
   ```
   drive the browser once to generate a small wiki and confirm the chat WebSocket connects through basic auth,
   redeploy `app`, run the smoke again, and delete the scratch project.

## Bumping DeepWiki-Open

1. Read the commits between the pinned commit and the candidate, especially `src/utils/websocketClient.ts`,
   `src/app/[owner]/[repo]/slides/page.tsx`, `.../workshop/page.tsx` (the patched files), `next.config.ts`
   (rewrites), `api/main.py` (ports/host), `api/routers/*` (paths the browser hits directly), `package.json`
   and `api/pyproject.toml`/`api/poetry.lock`.
2. Change `ARG DEEPWIKI_COMMIT` in `images/app/Dockerfile`.
3. If a patched file changed, `patch-source.mjs` stops with its new hash: re-read the file, adjust the patch
   (indentation-tolerant regex for the slides/workshop block), and record the new hash.
4. If `package.json`/`package-lock.json` changed, the build stops at the hash check: regenerate
   `images/app/deps` (`npm audit fix --package-lock-only --legacy-peer-deps` on upstream's files) and update the
   two hashes. Re-run OSV/pip-audit on `api/poetry.lock` and update `UPSTREAM.md` (and the gitpython pin if the
   lock already moved past 3.1.62).
5. Build and run the suites.

### Breaking-change checklist

- [ ] **New browser-direct backend paths** (beyond `/ws/*` and `/codemap/*`): add them to the `@backend` matcher
      in `images/app/Caddyfile`, or they will be routed to Next.js and 404.
- [ ] The API stops reading `PORT` from the environment, or the Next.js standalone server changes how it binds:
      update the port overrides in `images/app/entrypoint.sh`.
- [ ] Caddy's `basic_auth` directive or `caddy hash-password` flags change across a Caddy major: pin and adjust.
- [ ] A new upstream auth system worth using instead of basic auth (e.g. real accounts): reconsider the
      front-door design.
- [ ] The `.adalflow` data directory path or `DEEPWIKI_CONFIG_DIR` changes: update the volume mount and the
      entrypoint.

## Rollback

Point the template's `app` image back at the previous tag. The `.adalflow` volume holds generated wikis and
caches only (regenerable), so a rollback risks at most re-generating wikis, not losing irreplaceable data.
