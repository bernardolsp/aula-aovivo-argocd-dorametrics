#!/usr/bin/env bash
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"

# access.sh pushgateway deve estar aberto em outro terminal.
# Cada PUT substitui a mesma coorte; repetir o script não soma novas entregas.
for arquivo in "$dir"/dados/*.prom; do
  echo "Enviando $(basename "$arquivo")"
  curl --fail --silent --show-error --request PUT \
    --data-binary "@$arquivo" http://localhost:9091/metrics/job/dora-demo
  sleep 15
done
