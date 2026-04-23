#!/usr/bin/env bash
# Send one event per minute to a Tiler data source.
# Wire into cron / systemd / supervisor for production use.
#
# Required env: BASE_URL, TILER_TOKEN, SOURCE_SLUG
# Optional env: INTERVAL_SECONDS (default 60)

set -euo pipefail

: "${BASE_URL:?BASE_URL is required}"
: "${TILER_TOKEN:?TILER_TOKEN is required}"
: "${SOURCE_SLUG:?SOURCE_SLUG is required}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-60}"

while true; do
  # Replace this with whatever real measurement you collect.
  duration=$(awk 'BEGIN { srand(); print int(rand() * 1000) / 10 }')

  status="ok"
  payload=$(printf '{"status":"%s","duration":%s,"source_ref":"evt_%s"}' \
                    "$status" "$duration" "$(date +%s)")

  curl -sS -o /dev/null -w "%{http_code}\n" \
       -X POST "$BASE_URL/tiler/ingest/$SOURCE_SLUG" \
       -H "X-Tiler-Token: $TILER_TOKEN" \
       -H "Content-Type: application/json" \
       -d "$payload"

  sleep "$INTERVAL_SECONDS"
done
