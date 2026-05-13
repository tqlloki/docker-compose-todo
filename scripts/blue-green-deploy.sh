#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/todo-api}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
NEW_IMAGE="${NEW_IMAGE:?Missing NEW_IMAGE}"
DOMAIN="${DOMAIN:?Missing DOMAIN}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:?Missing LETSENCRYPT_EMAIL}"
MONGO_URI="${MONGO_URI:-mongodb://mongo:27017/todoapp}"
STATE_FILE="${STATE_FILE:-.active-slot}"
HEALTH_PATH="${HEALTH_PATH:-/health}"
HEALTH_RETRIES="${HEALTH_RETRIES:-30}"
HEALTH_SLEEP="${HEALTH_SLEEP:-2}"

cd "$APP_DIR"

if [ -f "$STATE_FILE" ]; then
  ACTIVE_SLOT="$(cat "$STATE_FILE" | tr -d '[:space:]')"
else
  ACTIVE_SLOT="blue"
fi

if [ "$ACTIVE_SLOT" = "blue" ]; then
  INACTIVE_SLOT="green"
elif [ "$ACTIVE_SLOT" = "green" ]; then
  INACTIVE_SLOT="blue"
else
  echo "Invalid active slot '$ACTIVE_SLOT', expected blue or green" >&2
  exit 1
fi

ACTIVE_CONTAINER="todo-api-${ACTIVE_SLOT}"
INACTIVE_CONTAINER="todo-api-${INACTIVE_SLOT}"

# Preserve current images where possible, then set the inactive slot to the new image.
CURRENT_BLUE_IMAGE="$(docker inspect todo-api-blue --format '{{.Config.Image}}' 2>/dev/null || true)"
CURRENT_GREEN_IMAGE="$(docker inspect todo-api-green --format '{{.Config.Image}}' 2>/dev/null || true)"
BLUE_IMAGE_NAME="${CURRENT_BLUE_IMAGE:-$NEW_IMAGE}"
GREEN_IMAGE_NAME="${CURRENT_GREEN_IMAGE:-$NEW_IMAGE}"

if [ "$INACTIVE_SLOT" = "blue" ]; then
  BLUE_IMAGE_NAME="$NEW_IMAGE"
  BLUE_VIRTUAL_HOST=""
  BLUE_LETSENCRYPT_HOST=""
  GREEN_VIRTUAL_HOST="$DOMAIN"
  GREEN_LETSENCRYPT_HOST="$DOMAIN"
else
  GREEN_IMAGE_NAME="$NEW_IMAGE"
  GREEN_VIRTUAL_HOST=""
  GREEN_LETSENCRYPT_HOST=""
  BLUE_VIRTUAL_HOST="$DOMAIN"
  BLUE_LETSENCRYPT_HOST="$DOMAIN"
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

echo "Active slot: $ACTIVE_SLOT"
echo "Deploying new image to inactive slot: $INACTIVE_SLOT"
echo "New image: $NEW_IMAGE"

for i in 1 2 3 4 5; do
  docker compose -f "$COMPOSE_FILE" pull "api-${INACTIVE_SLOT}" && break
  echo "pull failed, retry $i/5..."
  sleep 10
done

docker compose -f "$COMPOSE_FILE" up -d nginx-proxy acme-companion mongo "api-${INACTIVE_SLOT}"

echo "Waiting for ${INACTIVE_CONTAINER}${HEALTH_PATH}"
for i in $(seq 1 "$HEALTH_RETRIES"); do
  if docker exec "$INACTIVE_CONTAINER" node -e "fetch('http://127.0.0.1:3000${HEALTH_PATH}').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" >/dev/null 2>&1; then
    echo "Healthcheck OK for $INACTIVE_SLOT"
    break
  fi
  if [ "$i" = "$HEALTH_RETRIES" ]; then
    echo "Healthcheck failed for $INACTIVE_SLOT. Traffic remains on $ACTIVE_SLOT." >&2
    docker logs "$INACTIVE_CONTAINER" --tail=100 || true
    exit 1
  fi
  sleep "$HEALTH_SLEEP"
done

# Switch traffic by assigning the domain to the new slot and clearing it from the old slot.
if [ "$INACTIVE_SLOT" = "blue" ]; then
  BLUE_VIRTUAL_HOST="$DOMAIN"
  BLUE_LETSENCRYPT_HOST="$DOMAIN"
  GREEN_VIRTUAL_HOST=""
  GREEN_LETSENCRYPT_HOST=""
else
  GREEN_VIRTUAL_HOST="$DOMAIN"
  GREEN_LETSENCRYPT_HOST="$DOMAIN"
  BLUE_VIRTUAL_HOST=""
  BLUE_LETSENCRYPT_HOST=""
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

echo "Switching traffic to $INACTIVE_SLOT"
docker compose -f "$COMPOSE_FILE" up -d "api-${ACTIVE_SLOT}" "api-${INACTIVE_SLOT}" nginx-proxy acme-companion

echo "$INACTIVE_SLOT" > "$STATE_FILE"

echo "Blue-green deploy finished. Active slot: $INACTIVE_SLOT"
docker compose -f "$COMPOSE_FILE" ps
