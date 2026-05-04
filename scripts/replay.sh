#!/usr/bin/env bash
set -euo pipefail

# Replays Okta audit events through the pipeline by sending them
# directly to RSigma's OTLP HTTP endpoint as JSON-encoded OTLP logs.
# Use this script to trigger detections manually after the stack is up.

RSIGMA_ADDR="${RSIGMA_ADDR:-http://localhost:9090}"
EVENTS_FILE="${1:-events/okta_audit.ndjson}"

if [ ! -f "$EVENTS_FILE" ]; then
  echo "Events file not found: $EVENTS_FILE"
  exit 1
fi

echo "Sending events to RSigma at $RSIGMA_ADDR ..."
echo ""

while IFS= read -r line; do
  event_type=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('eventType','unknown'))" 2>/dev/null || echo "unknown")
  echo "  -> $event_type"

  curl -s -X POST "$RSIGMA_ADDR/api/v1/events" \
    -H 'Content-Type: text/plain' \
    -d "$line" > /dev/null

  sleep 1
done < "$EVENTS_FILE"

echo ""
echo "All events sent. Check Grafana at http://localhost:3000 for:"
echo "  - Detection dashboard (RSigma Detections)"
echo "  - Alert rules firing with dynamic severity labels"
echo ""
echo "Prometheus metrics:"
curl -s "$RSIGMA_ADDR/metrics" 2>/dev/null | grep -E "rsigma_(detection|correlation)_matches_by_rule_total" || echo "  (no matches yet)"
