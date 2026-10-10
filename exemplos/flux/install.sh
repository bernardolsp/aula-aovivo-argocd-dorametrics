#!/usr/bin/env bash
set -euo pipefail
context="kind-${CLUSTER_NAME:-argo-dora-live}"
kubectl --context "$context" apply --server-side -f \
  https://github.com/fluxcd/flux2/releases/download/v2.9.6/install.yaml
kubectl --context "$context" -n flux-system wait deployment --all \
  --for=condition=Available --timeout=300s
