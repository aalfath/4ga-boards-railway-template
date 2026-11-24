# 4ga Boards for Railway: the official image, pinned by version and digest.
FROM ghcr.io/rargames/4gaboards:3.3.16@sha256:3638be98c24c8c30c6185c1c8990a8a62b6bd13c0bfcc299a18dc133226b80d7

# The start script runs as root only to prepare the volume, then drops to the
# image's own "node" user (as upstream's start.sh does).
USER root

# Upstream's .env holds placeholder values (SECRET_KEY=notsecretkey, a local
# DATABASE_URL). Remove it so a missing variable fails loudly instead of
# silently falling back to a weak secret.
RUN rm /app/.env

# Railway rejects health-check paths that contain a hyphen, so expose upstream's
# public, database-backed settings action (GET /api/core-settings-public) as
# GET /healthz too. The build fails if upstream's routes file changes shape.
RUN sed -i "s#^module.exports.routes = {#module.exports.routes = {\\n  'GET /healthz': 'core/show',#" /app/config/routes.js \
 && grep -q "'GET /healthz': 'core/show'" /app/config/routes.js

ENV NODE_ENV=production \
    TZ=UTC \
    PORT=1337 \
    DATA_DIR=/app/data

COPY --chmod=755 railway-start.sh /app/railway-start.sh
COPY --chown=node:node railway-init.js /app/railway-init.js

EXPOSE 1337
CMD ["/app/railway-start.sh"]
