#!/usr/bin/env bash
# Quick checks against a deployed environment.
# Usage: scripts/smoke-test.sh [namespace]
set -euo pipefail

NS="${1:-staging}"
LOCAL_PORT=18081

kubectl port-forward -n "$NS" service/webapp "$LOCAL_PORT":80 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT

# Wait up to 30 seconds for the port-forward to start answering
for i in $(seq 1 10); do
  if curl -fsS --max-time 3 "http://localhost:$LOCAL_PORT/health" >/dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 10 ]; then
    echo "SMOKE TEST FAILED: /health never answered"
    exit 1
  fi
  sleep 3
done

HEALTH=$(curl -fsS "http://localhost:$LOCAL_PORT/health")
HOME_PAGE=$(curl -fsS "http://localhost:$LOCAL_PORT/")
echo "/health -> $HEALTH"
echo "/       -> $HOME_PAGE"

echo "$HEALTH" | grep -q '"status":"ok"' || { echo "SMOKE TEST FAILED: bad /health"; exit 1; }
echo "$HOME_PAGE" | grep -q 'Hello from the CI/CD pipeline' || { echo "SMOKE TEST FAILED: bad /"; exit 1; }

echo "Smoke test passed"
