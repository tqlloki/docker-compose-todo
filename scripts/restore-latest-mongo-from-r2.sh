#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/todo-api}"
MONGO_CONTAINER="${MONGO_CONTAINER:-todo-mongo}"
RESTORE_DIR="${RESTORE_DIR:-/tmp/todo-api-restore}"
R2_BUCKET="${R2_BUCKET:?Missing R2_BUCKET}"
R2_ACCOUNT_ID="${R2_ACCOUNT_ID:?Missing R2_ACCOUNT_ID}"
R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:?Missing R2_ACCESS_KEY_ID}"
R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:?Missing R2_SECRET_ACCESS_KEY}"
R2_PREFIX="${R2_PREFIX:-mongodb}"
AWS_IMAGE="${AWS_IMAGE:-amazon/aws-cli:2.15.57}"
ENDPOINT_URL="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

mkdir -p "$RESTORE_DIR"
cd "$APP_DIR"

echo "Finding latest backup in s3://${R2_BUCKET}/${R2_PREFIX}/"
LATEST_KEY="$(docker run --rm \
  -e AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  -e AWS_DEFAULT_REGION="auto" \
  "$AWS_IMAGE" \
  s3 ls "s3://${R2_BUCKET}/${R2_PREFIX}/" --endpoint-url "$ENDPOINT_URL" | \
  awk '/todo-mongo-.*\.archive\.tar\.gz$/ {print $4}' | sort | tail -1)"

if [ -z "$LATEST_KEY" ]; then
  echo "No backup found in R2" >&2
  exit 1
fi

echo "Downloading latest backup: $LATEST_KEY"
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  -e AWS_DEFAULT_REGION="auto" \
  -v "${RESTORE_DIR}:/restore" \
  "$AWS_IMAGE" \
  s3 cp "s3://${R2_BUCKET}/${R2_PREFIX}/${LATEST_KEY}" "/restore/${LATEST_KEY}" \
  --endpoint-url "$ENDPOINT_URL"

tar -C "$RESTORE_DIR" -xzf "${RESTORE_DIR}/${LATEST_KEY}"
ARCHIVE_FILE="${LATEST_KEY%.tar.gz}"

if ! docker ps --format '{{.Names}}' | grep -qx "$MONGO_CONTAINER"; then
  echo "Starting MongoDB container"
  docker compose -f docker-compose.prod.yml up -d mongo
fi

echo "Restoring MongoDB from $ARCHIVE_FILE"
docker cp "${RESTORE_DIR}/${ARCHIVE_FILE}" "$MONGO_CONTAINER:/tmp/${ARCHIVE_FILE}"
docker exec "$MONGO_CONTAINER" mongorestore --drop --archive="/tmp/${ARCHIVE_FILE}"
docker exec "$MONGO_CONTAINER" rm -f "/tmp/${ARCHIVE_FILE}" >/dev/null 2>&1 || true

echo "Restore finished from: $LATEST_KEY"
