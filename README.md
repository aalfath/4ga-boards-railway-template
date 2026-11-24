[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/4ga-boards?utm_medium=integration&utm_source=button&utm_campaign=4ga-boards)

# 4ga Boards on Railway

Railway template for [4ga Boards](https://github.com/RARgames/4gaBoards), a real-time kanban board for teams (projects, boards, lists, cards, tasks, comments and attachments). MIT licence.

## What it deploys

| Service | Source | Purpose |
|---|---|---|
| `4ga Boards` | this repo (`Dockerfile`) | The web app and API on port 1337, with a volume at `/app/data` |
| `Postgres` | Railway Postgres | Projects, boards, cards, users and settings |

- App version: **4ga Boards 3.3.16**, official image `ghcr.io/rargames/4gaboards:3.3.16@sha256:3638be98c24c8c30c6185c1c8990a8a62b6bd13c0bfcc299a18dc133226b80d7`.
- Uploads (avatars, project background images, card attachments) live on the app's volume at `/app/data`; everything else is in Postgres.
- Health check: `GET /healthz`, which the image maps to upstream's public settings action (it reads the database and answers without login).

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

## After deploy

1. Open the `4ga Boards` service, **Variables** tab, and copy `DEFAULT_ADMIN_PASSWORD`.
2. Open the public URL and sign in as `admin` with that password.
3. Change the admin e-mail and password under Settings, and add your team under Settings > Users. Public sign-up is off; turn it on (or limit it to e-mail domains) under Settings > Instance.

Optional upstream settings (Google/GitHub/Microsoft/OIDC sign-in, SMTP through 4ga's notification service, upload limits) are documented at <https://docs.4gaboards.com/docs/dev/install/docker-vars>. Add them as variables on the `4ga Boards` service.

## Resources

Runs on Railway's Free plan limits (0.5 GB RAM, 1 vCPU per service, one volume). The start script sizes the Node heap and the image-processing threads from the container's limits. Tested at 0.5 GB / 1 vCPU: the app peaked at about 210 MB with four parallel 36-megapixel image uploads and a board export; Postgres at about 105 MB.

## Updates

This template builds from this repository. When the pinned 4ga Boards version is bumped on `main`, Railway shows an "update available" notice in your project; read `CHANGELOG.md` and apply it when you are ready. Migrations run automatically on start. Back up the Postgres volume before a major upgrade.
