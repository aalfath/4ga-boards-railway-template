# 4ga Boards on Railway

Railway template for [4ga Boards](https://github.com/RARgames/4gaBoards), a real-time kanban board for teams (projects, boards, lists, cards, tasks, comments and attachments). MIT licence.

## What it deploys

| Service | Source | Purpose |
|---|---|---|
| `4ga Boards` | this repo (`Dockerfile`) | The web app and API on port 1337, with a volume at `/app/data` |
| `Postgres` | Railway Postgres | Projects, boards, cards, users and settings |

- App version: **4ga Boards 3.3.16**, official image `ghcr.io/rargames/4gaboards:3.3.16@sha256:3638be98c24c8c30c6185c1c8990a8a62b6bd13c0bfcc299a18dc133226b80d7`.
- Uploads (avatars, project background images, card attachments) live on the app's volume at `/app/data`; everything else is in Postgres.
- Health check: `GET /api/core-settings-public` (answers without login once the database is ready).

## Variables

| Variable | Default | Notes |
|---|---|---|
| `BASE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL. Change it if you add a custom domain. |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Reference to the Postgres service. |
| `SECRET_KEY` | `${{secret(64, "abcdef0123456789")}}` | Session signing key, generated. |
| `DEFAULT_ADMIN_USERNAME` | `admin` | Admin created on first boot only. |
| `DEFAULT_ADMIN_EMAIL` | `admin@example.com` | Admin e-mail; change it in the app afterwards. |
| `DEFAULT_ADMIN_PASSWORD` | `${{secret(24, …)}}` | Generated admin password. Read it in the service's Variables tab. |
| `DEFAULT_REGISTRATION_ENABLED` | `false` | Public sign-up stays off; the admin invites users or turns sign-up on in Settings. |
| `PORT` | `1337` | Port the app listens on. |

The admin variables are read only when the database is empty (first boot). Later changes to them do nothing; change the password in the app.

Optional upstream settings (Google/GitHub/Microsoft/OIDC sign-in, SMTP through 4ga's notification service, upload limits) are documented at <https://docs.4gaboards.com/docs/dev/install/docker-vars>. Add them as variables on the `4ga Boards` service.

## Resources

Runs on Railway's Free plan limits (0.5 GB RAM, 1 vCPU per service). The start script sizes the Node heap and the image-processing threads from the container's limits.

## Updates

This template builds from this repository. When the pinned 4ga Boards version is bumped on `main`, Railway shows an "update available" notice in your project; read `CHANGELOG.md` and apply it when you are ready. Migrations run automatically on start. Back up the Postgres volume before a major upgrade.
