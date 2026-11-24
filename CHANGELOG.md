# Changelog

Each entry is one version of this Railway template. Breaking changes are listed first.

## 3.3.16-1 (2026-11-24)

First release of the template.

- 4ga Boards 3.3.16 (`ghcr.io/rargames/4gaboards:3.3.16`, pinned by digest).
- Railway Postgres for data; one volume at `/app/data` for avatars, project backgrounds and attachments.
- The admin account is created on first boot with a generated password; public sign-up is off.
- Health check at `/healthz` (Railway rejects hyphens in health-check paths).
- Database migrations run on every start, under a lock, before the server opens its port.
- README: Deploy on Railway button (template code `4ga-boards`) and after-deploy steps.
