#!/usr/bin/env bash
# Print a deployment notification. Also posts to Slack if SLACK_WEBHOOK_URL is set.
# Usage: scripts/notify.sh <success|failure> <message>
set -euo pipefail

STATUS="${1:?Usage: notify.sh <success|failure> <message>}"
MESSAGE="${2:?Usage: notify.sh <success|failure> <message>}"

echo "NOTIFICATION [$STATUS]: $MESSAGE"

if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  curl -fsS -X POST -H 'Content-Type: application/json' \
    -d "{\"text\":\"[$STATUS] $MESSAGE\"}" "$SLACK_WEBHOOK_URL" >/dev/null
fi
