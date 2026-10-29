#!/usr/bin/env bash
# Mede o tempo de self-healing (recriação de pod até 3/3 Ready) e erros HTTP durante a queda.
# Uso: ./scripts/measure-selfheal.sh [N] (padrão N=5; grava em relatorio/dados/selfheal.csv)

set -euo pipefail

cd "$(dirname "$0")/.."
export LC_NUMERIC=C

NS="${NS:-ha-demo}"
N="${1:-5}"

if ! [[ "$N" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERRO: O número de execuções N deve ser um inteiro positivo (ex.: ./scripts/measure-selfheal.sh 5)." >&2
  exit 1
fi

URL="${URL:-$(minikube service api -n "$NS" --url)}"
CSV_FILE="relatorio/dados/selfheal.csv"

mkdir -p "$(dirname "$CSV_FILE")"
echo "execucao,segundos_ate_ready,erros_http,total_requisicoes" > "$CSV_FILE"

printf '==> Iniciando medição de self-healing (%s execuções) em %s\n' "$N" "${URL%/}"

for execucao in $(seq 1 "$N"); do
  kubectl rollout status deployment/api -n "$NS" --timeout=120s >/dev/null

  # Aguarda estabilizar 3 pods ativos (DELETING == <none>) e Ready (READY == True) antes da rodada
  while true; do
    prontos_ativos="$(kubectl get pods -n "$NS" -l app=api \
      -o custom-columns='NAME:.metadata.name,DELETING:.metadata.deletionTimestamp,READY:.status.conditions[?(@.type=="Ready")].status' \
      --no-headers | awk '$2 == "<none>" && $3 == "True" { c++ } END { print c+0 }')"
    if [[ "$prontos_ativos" -ge 3 ]]; then
      break
    fi
    sleep 0.2
  done

  pod_alvo="$(kubectl get pods -n "$NS" -l app=api \
    -o custom-columns='NAME:.metadata.name,DELETING:.metadata.deletionTimestamp,READY:.status.conditions[?(@.type=="Ready")].status' \
    --no-headers | awk '$2 == "<none>" && $3 == "True" { print $1; exit }')"

  if [[ -z "$pod_alvo" ]]; then
    echo "ERRO: Nenhum pod da API encontrado no namespace '$NS'." >&2
    exit 1
  fi

  printf '[Execução %d/%d] Deletando pod %s...\n' "$execucao" "$N" "$pod_alvo"

  erros_http=0
  total_requisicoes=0
  t0="$(date +%s.%N)"

  kubectl delete pod "$pod_alvo" -n "$NS" --wait=false >/dev/null

  while true; do
    total_requisicoes=$((total_requisicoes + 1))
    if ! curl -s -f -m 1 "${URL%/}/api/whoami" >/dev/null 2>&1; then
      erros_http=$((erros_http + 1))
    fi

    ready_replicas="$(kubectl get deploy api -n "$NS" -o jsonpath='{.status.readyReplicas}')"
    ready_replicas="${ready_replicas:-0}"

    if [[ "$ready_replicas" -ge 3 ]]; then
      novos_prontos="$(kubectl get pods -n "$NS" -l app=api \
        -o custom-columns='NAME:.metadata.name,DELETING:.metadata.deletionTimestamp,READY:.status.conditions[?(@.type=="Ready")].status' \
        --no-headers | awk -v alvo="$pod_alvo" '$1 != alvo && $2 == "<none>" && $3 == "True" { c++ } END { print c+0 }')"
      if [[ "$novos_prontos" -ge 3 ]]; then
        break
      fi
    fi

    sleep 0.1
  done

  t1="$(date +%s.%N)"
  segundos_ate_ready="$(awk -v t0="$t0" -v t1="$t1" 'BEGIN { printf "%.2f", t1 - t0 }')"

  echo "${execucao},${segundos_ate_ready},${erros_http},${total_requisicoes}" >> "$CSV_FILE"
  printf '[Execução %d/%d] Recuperado em %ss (erros HTTP: %d / %d requisições)\n' \
    "$execucao" "$N" "$segundos_ate_ready" "$erros_http" "$total_requisicoes"
done

printf '==> Concluído! Dados salvos em %s:\n' "$CSV_FILE"
cat "$CSV_FILE"
