#!/usr/bin/env bash
set -euo pipefail
context="kind-${CLUSTER_NAME:-argo-dora-live}"
dir="$(cd "$(dirname "$0")" && pwd)"
kubectl --context "$context" -n argocd create configmap plain-manifest-config \
  --from-file="$dir/plugin.yaml" --dry-run=client -o yaml | kubectl --context "$context" apply -f -
kubectl --context "$context" -n argocd patch deployment argocd-repo-server \
  --type strategic --patch-file "$dir/sidecar-patch.yaml"
# A montagem subPath precisa de um pod novo para receber mudanças no ConfigMap.
kubectl --context "$context" -n argocd rollout restart deployment/argocd-repo-server
kubectl --context "$context" -n argocd rollout status deployment/argocd-repo-server --timeout=180s
kubectl --context "$context" apply -f "$dir/application.yaml"
