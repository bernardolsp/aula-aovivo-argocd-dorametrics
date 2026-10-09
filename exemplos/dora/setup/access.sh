#!/usr/bin/env bash
set -euo pipefail
context="kind-${CLUSTER_NAME:-argo-dora-live}"
case "${1:-argocd}" in
  argocd) exec kubectl --context "$context" -n argocd port-forward svc/argocd-server 8080:443 ;;
  grafana) exec kubectl --context "$context" -n monitoring port-forward svc/grafana 3000:3000 ;;
  prometheus) exec kubectl --context "$context" -n monitoring port-forward svc/prometheus 9090:9090 ;;
  app) exec kubectl --context "$context" -n production port-forward svc/loja 8081:8080 ;;
  *) echo "uso: $0 [argocd|grafana|prometheus|app]" >&2; exit 2 ;;
esac
