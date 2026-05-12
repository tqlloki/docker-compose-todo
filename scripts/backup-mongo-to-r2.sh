#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/todo-api}"
MONGO_CONTAINER="${MONGO_CONTAINER:-todo-mongo}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/todo-api-backups}"
R2_BUCKET="${R2_BUCKET:?Missing R2_BUCKET}"
R2_ACCOUNT_ID="${R2_ACCOUNT_ID:?Missing R2_ACCOUNT_ID}"
R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:?Missing R2_ACCESS_KEY_ID}"
R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:?Missing R2_SECRET_ACCESS_KEY}"
R2_PREFIX="${R2_PREFIX:-mongodb}"
AWS_IMAGE="${AWS_IMAGE:-amazon/aws-cli:2.15.57}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE_NAME="todo-mongo-${TIMESTAMP}.archive"
TARBALL_NAME="${ARCHIVE_NAME}.tar.gz"
ENDPOINT_URL="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

mkdir -p "$BACKUP_DIR"
cd "$APP_DIR"

if ! docker ps --format '{{.Names}}' | grep -qx "$MONGO_CONTAINER"; then
  echo "Mongo container '$MONGO_CONTAINER' is not running" >&2
  exit 1
fi

echo "Creating MongoDB dump: $ARCHIVE_NAME"
docker exec "$MONGO_CONTAINER" mongodump --archive="/tmp/${ARCHIVE_NAME}"
docker cp "$MONGO_CONTAINER:/tmp/${ARCHIVE_NAME}" "${BACKUP_DIR}/${ARCHIVE_NAME}"
docker exec "$MONGO_CONTAINER" rm -f "/tmp/${ARCHIVE_NAME}" >/dev/null 2>&1 || true

echo "Compressing backup: $TARBALL_NAME"
tar -C "$BACKUP_DIR" -czf "${BACKUP_DIR}/${TARBALL_NAME}" "$ARCHIVE_NAME"
rm -f "${BACKUP_DIR}/${ARCHIVE_NAME}"

echo "Uploading to R2: s3://${R2_BUCKET}/${R2_PREFIX}/${TARBALL_NAME}"
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  -e AWS_DEFAULT_REGION="auto" \
  -v "${BACKUP_DIR}:/backup:ro" \
  "$AWS_IMAGE" \
  s3 cp "/backup/${TARBALL_NAME}" "s3://${R2_BUCKET}/${R2_PREFIX}/${TARBALL_NAME}" \
  --endpoint-url "$ENDPOINT_URL"

echo "Backup uploaded successfully: ${R2_PREFIX}/${TARBALL_NAME}"

# Keep only recent local backup tarballs to avoid filling disk.
find "$BACKUP_DIR" -type f -name 'todo-mongo-*.archive.tar.gz' -mtime +3 -delete
