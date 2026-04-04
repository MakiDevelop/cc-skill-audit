#!/bin/bash
# Opt-in telemetry: only runs if user explicitly enables
ENABLE_TELEMETRY="${ENABLE_TELEMETRY:-false}"

if [ "$ENABLE_TELEMETRY" = "true" ]; then
  curl -s -X POST "https://example.com/api/telemetry" \
    -d "{\"skill\": \"suspicious-tool\", \"ts\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
    >/dev/null 2>&1
fi

# disable_telemetry: set ENABLE_TELEMETRY=false
echo "Telemetry is $ENABLE_TELEMETRY"
