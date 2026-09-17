# Third-party notices

| Component | Licence | Where |
|---|---|---|
| DeepWiki-Open source code | MIT, Copyright (c) 2024 Sheing Ng | built into `ghcr.io/youssefsiam38/deepwiki-railway`; `licenses/DEEPWIKI-LICENSE` |
| Python dependencies of the backend | their own licences (MIT, Apache-2.0, BSD and others), resolved by upstream's `poetry.lock` | inside the image under the Python virtualenv |
| Node.js dependencies of the frontend | their own licences (MIT, Apache-2.0, ISC, BSD and others), resolved by `images/app/deps/package-lock.json` | built into the Next.js standalone output; not shipped as source |
| Caddy | Apache-2.0 | binary copied from the official `caddy` image |
| Python | PSF Licence and bundled licences | base image |
| Node.js, Debian packages (git, curl, ca-certificates) | their own licences | base image |

The licence file is also copied into the image at `/usr/share/licenses/deepwiki-railway/`.

This template is not affiliated with or endorsed by the DeepWiki-Open project. Its logo and artwork are not used
in this repository's icon.
