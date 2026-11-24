#!/bin/bash
# Start 4ga Boards on Railway: check settings, put every upload folder on the
# one volume, run migrations (and the first-boot admin seed) under a lock,
# then start the server. Any failure exits non-zero so Railway restarts it.
set -euo pipefail

log() { echo "[railway-start] $*"; }
die() { echo "[railway-start] ERROR: $*" >&2; exit 1; }

# --- Public URL --------------------------------------------------------------
valid_url() { node -e 'const u=new URL(process.argv[1]); if(!/^https?:$/.test(u.protocol)||!u.hostname) process.exit(1)' "$1" 2>/dev/null; }
if [ -z "${BASE_URL:-}" ] || ! valid_url "$BASE_URL"; then
  if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    BASE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
  else
    die "BASE_URL is empty or invalid and the service has no public domain. Add a domain in Settings > Networking, or set BASE_URL."
  fi
fi
export BASE_URL="${BASE_URL%/}"

# --- Required settings -------------------------------------------------------
[ -n "${DATABASE_URL:-}" ] || die "DATABASE_URL is not set (it should reference the Postgres service)."
[ -n "${SECRET_KEY:-}" ] || die "SECRET_KEY is not set."
[ "${#SECRET_KEY}" -ge 32 ] || die "SECRET_KEY must be at least 32 characters."

# First-boot admin (used only when the database is empty) and closed sign-up.
export DEFAULT_ADMIN_USERNAME="${DEFAULT_ADMIN_USERNAME:-admin}"
export DEFAULT_ADMIN_EMAIL="${DEFAULT_ADMIN_EMAIL:-admin@example.com}"
export DEFAULT_ADMIN_NAME="${DEFAULT_ADMIN_NAME:-Administrator}"
export DEFAULT_REGISTRATION_ENABLED="${DEFAULT_REGISTRATION_ENABLED:-false}"
if [ -z "${DEFAULT_ADMIN_PASSWORD:-}" ] || [ "${DEFAULT_ADMIN_PASSWORD}" = "demo" ]; then
  die "DEFAULT_ADMIN_PASSWORD is not set. Refusing to start: upstream would create the admin as demo/demo."
fi

# Railway's proxy sets X-Forwarded-*; trust it for client IPs and rate limits.
export TRUST_PROXY="${TRUST_PROXY:-true}"

# --- Size to the container, not the host ------------------------------------
cpus=1
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [ "${quota:-max}" != "max" ] && [ -n "${period:-}" ]; then
    cpus=$(( (quota + period - 1) / period ))
  fi
fi
[ "$cpus" -ge 1 ] || cpus=1
[ "$cpus" -le 4 ] || cpus=4
export SHARP_CONCURRENCY="${SHARP_CONCURRENCY:-$cpus}"
export UV_THREADPOOL_SIZE="${UV_THREADPOOL_SIZE:-4}"

mem_mb=0
if [ -r /sys/fs/cgroup/memory.max ] && [ "$(cat /sys/fs/cgroup/memory.max)" != "max" ]; then
  mem_mb=$(( $(cat /sys/fs/cgroup/memory.max) / 1048576 ))
fi
if [ "$mem_mb" -gt 0 ]; then
  heap=$(( mem_mb * 60 / 100 ))
  [ "$heap" -le 1536 ] || heap=1536
  [ "$heap" -ge 128 ] || heap=128
  case " ${NODE_OPTIONS:-} " in *max-old-space-size*) ;; *) export NODE_OPTIONS="--max-old-space-size=${heap} ${NODE_OPTIONS:-}";; esac
  log "memory limit ${mem_mb} MB, Node heap ${heap} MB, ${cpus} CPU(s)"
fi

# --- Storage: one volume for avatars, backgrounds and attachments -----------
DATA_DIR="${DATA_DIR:-/app/data}"
mkdir -p "$DATA_DIR"
if [ "$(id -u)" = "0" ]; then
  for pair in \
      "/app/public/user-avatars:user-avatars" \
      "/app/public/project-background-images:project-background-images" \
      "/app/private/attachments:attachments"; do
    target="${pair%%:*}"; dest="$DATA_DIR/${pair##*:}"
    mkdir -p "$dest"
    if [ -L "$target" ]; then
      continue
    fi
    if [ -d "$target" ]; then
      if [ "$(stat -c %d "$target")" != "$(stat -c %d "$(dirname "$target")")" ]; then
        log "warning: $target is a separate mount; leaving it in place"
        continue
      fi
      cp -a "$target"/. "$dest"/ 2>/dev/null || true
      rm -r "$target"
    fi
    ln -s "$dest" "$target"
  done
  if [ "$(stat -c %U "$DATA_DIR")" != "node" ]; then
    chown -R node:node "$DATA_DIR"
  fi
  chown -h node:node /app/public/user-avatars /app/public/project-background-images /app/private/attachments 2>/dev/null || true
  mkdir -p /app/private/exports /app/logs /app/.tmp
  chown node:node /app /app/public /app/private /app/private/exports /app/logs /app/.tmp
  RUN_AS=(su-exec node)
else
  RUN_AS=()
fi

# --- Database: migrations and the first-boot admin, under a lock -------------
log "running database migrations"
"${RUN_AS[@]}" node /app/railway-init.js || die "database setup failed"

log "starting 4ga Boards on port ${PORT:-1337} (${BASE_URL})"
cd /app
exec "${RUN_AS[@]}" node app.js --prod
