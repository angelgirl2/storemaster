#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p backups
STAMP="$(date +%Y%m%d_%H%M%S)"
docker compose -f docker-compose.prod.yml exec -T db \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "backups/storemaster_${STAMP}.dump"
echo "Backup written to backups/storemaster_${STAMP}.dump"
