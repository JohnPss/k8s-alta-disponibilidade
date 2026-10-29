#!/usr/bin/env bash
# Mede o tempo de self-healing (recriação de pod até 3/3 Ready) e erros HTTP durante a queda.
# Uso: ./scripts/measure-selfheal.sh [N] (padrão N=5; grava em relatorio/dados/selfheal.csv)

set -euo pipefail

cd "$(dirname "$0")/.."
export LC_NUMERIC=C

NS="${NS:-ha-demo}"
if [[ "$NS" != "ha-demo" ]]; then
  echo "ERRO: O namespace suportado pelo projeto é estritamente 'ha-demo' (ver docs/CONTRATOS.md)." >&2
  exit 1
fi
N="${1:-5}"

if ! [[ "$N" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERRO: O número de execuções N deve ser um inteiro positivo (ex.: ./scripts/measure-selfheal.sh 5)." >&2
  exit 1
fi

# Timestamp portátil com alta precisão (GNU date no Linux ou fallback Python no macOS/BSD)
if date +%s.%N 2>/dev/null | grep -qv '%N'; then
  get_timestamp() { date +%s.%N; }
elif command -v python3 >/dev/null 2>&1; then
  get_timestamp() { python3 -c 'import time; print(f"{time.time():.6f}")'; }
else
  get_timestamp() { date +%s; }
fi

URL="${URL:-$(minikube service api -n "$NS" --url)}"
CSV_FILE="relatorio/dados/selfheal.csv"

mkdir -p "$(dirname "$CSV_FILE")"
echo "execucao,segundos_ate_ready,erros_http,total_requisicoes" > "$CSV_FILE"

printf '==> Iniciando medição de self-healing (%s execuções) em %s\n' "$N" "${URL%/}"

for execucao in $(seq 1 "$N"); do
  kubectl rollout status deployment/api -n "$NS" --timeout=120s >/dev/null

  # Aguarda estabilizar 3 pods ativos (DELETING == <none>) e Ready (READY == True) antes da rodada
  inicio_espera=$SECONDS
  while true; do
    if (( SECONDS - inicio_espera > 60 )); then
      echo "ERRO: Timeout (60s) aguardando estabilização de 3 pods prontos da API antes da rodada $execucao." >&2
      exit 1
    fi
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
  t0="$(get_timestamp)"

  kubectl delete pod "$pod_alvo" -n "$NS" --wait=false >/dev/null

  inicio_recuperacao=$SECONDS
  while true; do
    if (( SECONDS - inicio_recuperacao > 60 )); then
      echo "ERRO: Timeout (60s) aguardando recuperação da réplica após deletar o pod $pod_alvo (rodada $execucao)." >&2
      exit 1
    fi
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

  t1="$(get_timestamp)"
  segundos_ate_ready="$(awk -v t0="$t0" -v t1="$t1" 'BEGIN { printf "%.2f", t1 - t0 }')"

  echo "${execucao},${segundos_ate_ready},${erros_http},${total_requisicoes}" >> "$CSV_FILE"
  printf '[Execução %d/%d] Recuperado em %ss (erros HTTP: %d / %d requisições)\n' \
    "$execucao" "$N" "$segundos_ate_ready" "$erros_http" "$total_requisicoes"
done

printf '==> Concluído! Dados salvos em %s:\n' "$CSV_FILE"
cat "$CSV_FILE"
