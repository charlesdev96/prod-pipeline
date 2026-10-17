#!/usr/bin/env bash
# Blue-green deploy to production.
# Usage: scripts/deploy.sh <image> [namespace]
#
# 1. Find which color is live (blue or green)
# 2. Deploy the new image to the OTHER color
# 3. Wait until its pods are ready
# 4. Switch the Service to the new color
# 5. Watch /health for HEALTH_WINDOW seconds - if it fails, switch back (rollback)
set -euo pipefail

IMAGE="${1:?Usage: deploy.sh <image> [namespace]}"
NS="${2:-production}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"   # max wait for new pods to be ready
HEALTH_WINDOW="${HEALTH_WINDOW:-300}"        # seconds to watch health after the switch (5 minutes)
HEALTH_INTERVAL=10                           # seconds between health checks
LOCAL_PORT=18080

DIR="$(cd "$(dirname "$0")/.." && pwd)/k8s/production"

# Step 1: which color is live right now?
LIVE=$(kubectl get service webapp -n "$NS" -o jsonpath='{.spec.selector.version}' 2>/dev/null || true)
if [ "$LIVE" = "blue" ]; then
  NEW="green"
else
  NEW="blue"
fi
echo "Live color: ${LIVE:-none (first deploy)}  ->  deploying to: $NEW"

switch_to() {
  kubectl patch service webapp -n "$NS" \
    -p "{\"spec\":{\"selector\":{\"app\":\"webapp\",\"version\":\"$1\"}}}"
}

rollback() {
  if [ -n "$LIVE" ]; then
    echo "ROLLBACK: switching traffic back to $LIVE"
    switch_to "$LIVE"
  else
    echo "No previous version to roll back to (this was the first deploy)"
  fi
}

# Step 2: create namespace and Service (first deploy only), then deploy the new color
kubectl apply -f "$DIR/namespace.yaml"
if ! kubectl get service webapp -n "$NS" >/dev/null 2>&1; then
  kubectl apply -f "$DIR/service.yaml"
fi
sed "s|IMAGE_PLACEHOLDER|$IMAGE|g" "$DIR/deployment-$NEW.yaml" | kubectl apply -f -

# Step 3: wait for the new pods. Traffic is still on the old color, so nothing is lost.
if ! kubectl rollout status "deployment/app-$NEW" -n "$NS" --timeout="$ROLLOUT_TIMEOUT"; then
  echo "New pods did not become ready. Traffic was never switched, so the live version is unaffected."
  exit 1
fi

# Step 4: switch traffic
switch_to "$NEW"

# Step 5: health check, then rollback if it fails
kubectl port-forward -n "$NS" service/webapp "$LOCAL_PORT":80 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 3

END=$((SECONDS + HEALTH_WINDOW))
while [ "$SECONDS" -lt "$END" ]; do
  if curl -fsS --max-time 5 "http://localhost:$LOCAL_PORT/health" >/dev/null; then
    echo "Health check OK ($((END - SECONDS))s left in the window)"
  else
    echo "Health check FAILED"
    rollback
    exit 1
  fi
  sleep "$HEALTH_INTERVAL"
done

echo "Deploy finished: $NEW is live."
if [ -n "$LIVE" ]; then
  echo "$LIVE stays running so we can switch back quickly."
fi
