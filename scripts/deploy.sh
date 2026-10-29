#!/usr/bin/env bash
# Aplica os manifestos Kubernetes, aguarda os rollouts e mostra a URL da API.
# Uso: ./scripts/deploy.sh (opcional: NS=ha-demo ./scripts/deploy.sh)

set -euo pipefail

NS="${NS:-ha-demo}"
if [[ "$NS" != "ha-demo" ]]; then
  echo "ERRO: O namespace suportado pelo projeto é estritamente 'ha-demo' (ver docs/CONTRATOS.md)." >&2
  exit 1
fi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

printf '\033[34m==> Aplicando manifestos Kubernetes...\033[0m\n'
kubectl apply -f k8s/

printf '\033[34m==> Aguardando rollout do PostgreSQL...\033[0m\n'
kubectl rollout status statefulset/postgres -n "$NS" --timeout=180s

printf '\033[34m==> Aguardando rollout da API...\033[0m\n'
kubectl rollout status deployment/api -n "$NS" --timeout=180s

printf '\033[34m==> Pods no namespace %s:\033[0m\n' "$NS"
kubectl get pods -n "$NS" -o wide

URL="$(minikube service api -n "$NS" --url)"
printf '\033[32mURL: %s\033[0m\n' "$URL"