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

# Upload via boto3 (awscli isn't packaged for Ubuntu 24.04 main).
export AWS_ACCESS_KEY_ID="$SPACES_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$SPACES_SECRET_ACCESS_KEY"
/opt/reviewlens/venv/bin/python - "$TMP_DIR/reviewlens-${STAMP}.tar.gz" <<'PY'
import os, sys, boto3
src, region, bucket = sys.argv[1], os.environ["SPACES_REGION"], os.environ["SPACES_BUCKET"]
s3 = boto3.client("s3", endpoint_url=f"https://{region}.digitaloceanspaces.com", region_name=region)
key = f"postgres/{os.path.basename(src)}"
with open(src, "rb") as f:
    s3.upload_fileobj(f, bucket, key)
print(f"[backup] uploaded {key} to {bucket}")
PY
