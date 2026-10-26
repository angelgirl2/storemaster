#!/usr/bin/env bash
set -euo pipefail

: "${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN in your shell (never commit it)}"
: "${CLOUDFLARE_ACCOUNT_ID:?Set CLOUDFLARE_ACCOUNT_ID}"
: "${PRIMARY_API_ORIGIN:?Set the direct Railway API origin}"
: "${FALLBACK_API_ORIGIN:?Set the direct VPS API origin}"
: "${FAILOVER_CONTROL_KEY:?Set a secret failover control key of at least 32 characters}"
if [ "${#FAILOVER_CONTROL_KEY}" -lt 32 ]; then echo "FAILOVER_CONTROL_KEY must be at least 32 characters" >&2; exit 1; fi
R2_BUCKET="${R2_BUCKET:-storemaster-backups}"

cd "$(dirname "$0")"
export CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID
if npx --yes wrangler@4 r2 bucket info "$R2_BUCKET" --json >/dev/null 2>&1; then
  echo "R2 bucket already exists: $R2_BUCKET"
else
  npx --yes wrangler@4 r2 bucket create "$R2_BUCKET"
fi
npx --yes wrangler@4 deploy --config wrangler.toml \
  --var "PRIMARY_API_ORIGIN:$PRIMARY_API_ORIGIN" \
  --var "FALLBACK_API_ORIGIN:$FALLBACK_API_ORIGIN"
printf '%s' "$FAILOVER_CONTROL_KEY" | npx --yes wrangler@4 secret put FAILOVER_CONTROL_KEY --config wrangler.toml

echo "Worker deployed on workers.dev. No custom domain is required to test it; copy the assigned workers.dev URL from the Cloudflare dashboard."
echo "For business-critical production, attach a custom domain when one is available. Before failover, ensure both API origins use one authoritative PostgreSQL database or a reconciled/promoted replica."
