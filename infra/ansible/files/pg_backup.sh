#!/usr/bin/env bash
# Nightly PostgreSQL backup for ReviewLens.
#
# Runs pg_dump inside the review_lens-db container (Postgres accessory),
# compresses, and uploads to a DigitalOcean Spaces bucket. Keeps 30 days
# of dumps (bucket lifecycle expires older objects, see infra/storage.tf).
#
# Credentials are sourced from /opt/reviewlens/spaces.env (written by Ansible,
# mode 0600). Never commit real credentials.
set -euo pipefail

CONTAINER="${REVIEWLENS_DB_CONTAINER:-review_lens-db}"
DB_USER="${REVIEWLENS_DB_USER:-review_lens}"
DB_NAME="${REVIEWLENS_DB_NAME:-review_lens_production}"

# shellcheck source=/dev/null
. /opt/reviewlens/spaces.env

: "${SPACES_ACCESS_KEY_ID:?missing}"
: "${SPACES_SECRET_ACCESS_KEY:?missing}"
: "${SPACES_REGION:?missing}"
: "${SPACES_BUCKET:?missing}"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Dump all four Rails databases (primary + cache/queue/cable).
for name in "$DB_NAME" "${DB_NAME}_cache" "${DB_NAME}_queue" "${DB_NAME}_cable"; do
  echo "[backup] dumping $name"
  docker exec -e PGPASSWORD="$REVIEWLENS_DB_PASSWORD" "$CONTAINER" \
    pg_dump -U "$DB_USER" -d "$name" -Fc \
    > "$TMP_DIR/${name}-${STAMP}.dump"
done

tar -czf "$TMP_DIR/reviewlens-${STAMP}.tar.gz" -C "$TMP_DIR" .

AWS_ACCESS_KEY_ID="$SPACES_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$SPACES_SECRET_ACCESS_KEY" \
aws s3 cp "$TMP_DIR/reviewlens-${STAMP}.tar.gz" \
  "s3://${SPACES_BUCKET}/postgres/${STAMP}.tar.gz" \
  --endpoint-url "https://${SPACES_REGION}.digitaloceanspaces.com" \
  --region "$SPACES_REGION"

echo "[backup] uploaded reviewlens-${STAMP}.tar.gz to ${SPACES_BUCKET}/postgres/"
