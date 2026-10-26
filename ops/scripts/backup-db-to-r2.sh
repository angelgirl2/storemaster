#!/usr/bin/env bash
set -euo pipefail

# Required variables: POSTGRES_USER, POSTGRES_DB, R2_ACCOUNT_ID, R2_BUCKET,
# R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY. Keep credentials in ops/.env.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ -f "$ROOT/.env" ]]; then set -a; source "$ROOT/.env"; set +a; fi
for name in POSTGRES_USER POSTGRES_DB R2_ACCOUNT_ID R2_BUCKET R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY; do
  if [[ -z "${!name:-}" ]]; then echo "Missing required variable: $name (configure ops/.env or export it)" >&2; exit 2; fi
done
mkdir -p backups
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FILE="storemaster_${STAMP}.dump"

docker compose -f docker-compose.prod.yml exec -T db \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "backups/$FILE"

# The R2 credentials are mounted only into this short-lived CLI container.
docker run --rm \
  -v "$ROOT/backups:/work:ro" \
  -e AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  -e AWS_DEFAULT_REGION=auto \
  amazon/aws-cli:2 \
  s3 cp "/work/$FILE" "s3://$R2_BUCKET/postgres/$FILE" \
  --endpoint-url "https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com" \
  --only-show-errors

echo "PostgreSQL backup uploaded to Cloudflare R2: s3://$R2_BUCKET/postgres/$FILE"
