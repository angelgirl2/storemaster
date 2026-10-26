#!/usr/bin/env bash
set -euo pipefail

# Run once on the VPS after setting the R2_* and PostgreSQL variables in ops/.env.
OPS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_SCRIPT="$OPS_DIR/scripts/backup-db-to-r2.sh"
mkdir -p "$OPS_DIR/backups"
chmod 700 "$OPS_DIR/backups"
CRON_LINE="CRON_TZ=UTC
15 2 * * * /bin/bash '$BACKUP_SCRIPT' >> '$OPS_DIR/backups/r2-backup.log' 2>&1"
EXISTING="$(crontab -l 2>/dev/null || true)"
if printf '%s\n' "$EXISTING" | grep -Fq "$BACKUP_SCRIPT"; then
  echo "Cloudflare R2 backup cron entry already exists."
  exit 0
fi
{ printf '%s\n' "$EXISTING"; printf '%s\n' "$CRON_LINE"; } | crontab -
echo "Installed daily Cloudflare R2 backup at 02:15 UTC. Check $OPS_DIR/backups/r2-backup.log."
