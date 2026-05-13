#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/todo-api}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
DOMAIN="${DOMAIN:?Missing DOMAIN}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:?Missing LETSENCRYPT_EMAIL}"
MONGO_URI="${MONGO_URI:-mongodb://mongo:27017/todoapp}"
STATE_FILE="${STATE_FILE:-.active-slot}"

cd "$APP_DIR"
ACTIVE_SLOT="$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]' || echo blue)"
if [ "$ACTIVE_SLOT" = "blue" ]; then
  TARGET_SLOT="green"
elif [ "$ACTIVE_SLOT" = "green" ]; then
  TARGET_SLOT="blue"
else
  echo "Invalid active slot '$ACTIVE_SLOT'" >&2
  exit 1
fi

BLUE_IMAGE_NAME="$(docker inspect todo-api-blue --format '{{.Config.Image}}' 2>/dev/null || true)"
GREEN_IMAGE_NAME="$(docker inspect todo-api-green --format '{{.Config.Image}}' 2>/dev/null || true)"

if [ -z "$BLUE_IMAGE_NAME" ] || [ -z "$GREEN_IMAGE_NAME" ]; then
  echo "Both blue and green containers must exist before rollback." >&2
  exit 1
fi

if [ "$TARGET_SLOT" = "blue" ]; then
  BLUE_VIRTUAL_HOST="$DOMAIN"; BLUE_LETSENCRYPT_HOST="$DOMAIN"
  GREEN_VIRTUAL_HOST=""; GREEN_LETSENCRYPT_HOST=""
else
  GREEN_VIRTUAL_HOST="$DOMAIN"; GREEN_LETSENCRYPT_HOST="$DOMAIN"
  BLUE_VIRTUAL_HOST=""; BLUE_LETSENCRYPT_HOST=""
fi

cat > .env <<EOF_ENV
NODE_ENV=production
MONGO_URI=${MONGO_URI}
DOMAIN=${DOMAIN}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
BLUE_IMAGE_NAME=${BLUE_IMAGE_NAME}
GREEN_IMAGE_NAME=${GREEN_IMAGE_NAME}
BLUE_VIRTUAL_HOST=${BLUE_VIRTUAL_HOST}
GREEN_VIRTUAL_HOST=${GREEN_VIRTUAL_HOST}
BLUE_LETSENCRYPT_HOST=${BLUE_LETSENCRYPT_HOST}
GREEN_LETSENCRYPT_HOST=${GREEN_LETSENCRYPT_HOST}
EOF_ENV

echo "Rolling back traffic from $ACTIVE_SLOT to $TARGET_SLOT"
docker compose -f "$COMPOSE_FILE" up -d api-blue api-green nginx-proxy acme-companion
echo "$TARGET_SLOT" > "$STATE_FILE"
docker compose -f "$COMPOSE_FILE" ps
