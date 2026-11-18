#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-devops-demo}"
SERVICE="${SERVICE:-end-to-end-devops-app}"
LOCAL_PORT="${LOCAL_PORT:-8081}"

command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

kubectl rollout status "deployment/end-to-end-devops-app" \
  --namespace "$NAMESPACE" --timeout=180s

kubectl port-forward "service/$SERVICE" "$LOCAL_PORT:80" \
  --namespace "$NAMESPACE" >/tmp/devops-project-port-forward.log 2>&1 &
PORT_FORWARD_PID=$!
trap 'kill "$PORT_FORWARD_PID" 2>/dev/null || true' EXIT

for attempt in $(seq 1 30); do
  if curl --fail --silent "http://127.0.0.1:${LOCAL_PORT}/api"; then
    printf '\nLocal application verification passed.\n'
    exit 0
  fi
  sleep 2
done

cat /tmp/devops-project-port-forward.log >&2
printf 'Application endpoint did not become ready.\n' >&2
exit 1
