#!/usr/bin/env bash
set -euo pipefail

cluster="${CLUSTER_NAME:-argo-dora-live}"
context="kind-${cluster}"
root="$(cd "$(dirname "$0")/../../.." && pwd)"

for cmd in docker kind kubectl; do
  command -v "$cmd" >/dev/null || { echo "instale $cmd" >&2; exit 1; }
done

if ! kind get clusters | grep -qx "$cluster"; then
  kind create cluster --name "$cluster" --image kindest/node:v1.34.0 --wait 120s
fi

# Pré-carrega as imagens pequenas da aplicação e do hook.
docker pull nginx:1.28.0-alpine
docker pull busybox:1.37.0
kind load docker-image --name "$cluster" nginx:1.28.0-alpine busybox:1.37.0

kubectl --context "$context" create namespace argocd --dry-run=client -o yaml | kubectl --context "$context" apply -f -
kubectl --context "$context" apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.1/manifests/install.yaml
kubectl --context "$context" apply -f "$root/exemplos/dora/setup/infra.yaml"

kubectl --context "$context" -n monitoring create configmap prometheus-config \
  --from-file="$root/exemplos/dora/monitoring/prometheus.yml" --dry-run=client -o yaml | kubectl --context "$context" apply -f -
kubectl --context "$context" -n monitoring create configmap prometheus-rules \
  --from-file="$root/exemplos/dora/monitoring/rules.yaml" --dry-run=client -o yaml | kubectl --context "$context" apply -f -
kubectl --context "$context" -n monitoring create configmap grafana-datasource \
  --from-file="$root/exemplos/dora/monitoring/datasource.yaml" --dry-run=client -o yaml | kubectl --context "$context" apply -f -
kubectl --context "$context" -n monitoring create configmap grafana-provider \
  --from-file="$root/exemplos/dora/monitoring/provider.yaml" --dry-run=client -o yaml | kubectl --context "$context" apply -f -
kubectl --context "$context" -n monitoring create configmap dora-dashboard \
  --from-file="$root/exemplos/dora/monitoring/dashboard.json" --dry-run=client -o yaml | kubectl --context "$context" apply -f -

kubectl --context "$context" -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl --context "$context" -n argocd rollout status deployment/argocd-repo-server --timeout=300s
kubectl --context "$context" -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
# Também recarrega configuração se o setup for reexecutado.
kubectl --context "$context" -n monitoring rollout restart deployment/prometheus deployment/grafana
kubectl --context "$context" -n monitoring rollout status deployment/prometheus --timeout=300s
kubectl --context "$context" -n monitoring rollout status deployment/grafana --timeout=300s

echo "Pronto: $context. Aplique exemplos/dora/application.yaml e sincronize loja-prod."
echo "Argo CD: admin; senha abaixo. Grafana: admin/admin."
kubectl --context "$context" -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
echo
