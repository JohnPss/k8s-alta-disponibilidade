#!/usr/bin/env bash
# Gera carga contínua em /api/cpu com um pod busybox dentro do cluster para acionar o HPA.
# Ao receber Ctrl+C (SIGINT/SIGTERM), remove o pod gerador de carga imediatamente.
# Uso: ./scripts/load-hpa.sh (opcional: NS=ha-demo WORKERS=6 MS=200 ./scripts/load-hpa.sh)

set -euo pipefail

NS="${NS:-ha-demo}"
if [[ "$NS" != "ha-demo" ]]; then
  echo "ERRO: O namespace suportado pelo projeto é estritamente 'ha-demo' (ver docs/CONTRATOS.md)." >&2
  exit 1
fi

POD_NAME="${POD_NAME:-load}"
MS="${MS:-200}"
WORKERS="${WORKERS:-6}"

cleanup() {
  local exit_code=$?
  trap - INT TERM EXIT
  printf '\n\033[33m==> Encerrando carga e removendo pod %s no namespace %s...\033[0m\n' "$POD_NAME" "$NS"
  kubectl delete pod "$POD_NAME" -n "$NS" --ignore-not-found --grace-period=0 --force >/dev/null 2>&1 || true
  printf '\033[32m==> Pod %s removido.\033[0m\n' "$POD_NAME"
  if [[ "$exit_code" -eq 130 || "$exit_code" -eq 143 ]]; then
    exit 0
  fi
  exit "$exit_code"
}

trap cleanup INT TERM EXIT

kubectl delete pod "$POD_NAME" -n "$NS" --ignore-not-found --grace-period=0 --force >/dev/null 2>&1 || true

printf '\033[34m==> Iniciando pod gerador de carga (%s, %s fluxos em /api/cpu?ms=%s) no namespace %s...\033[0m\n' \
  "$POD_NAME" "$WORKERS" "$MS" "$NS"
printf '\033[34m==> Pressione Ctrl+C para parar a carga.\033[0m\n'

kubectl run "$POD_NAME" -n "$NS" \
  --image=busybox:1.36 \
  --image-pull-policy=IfNotPresent \
  --restart=Never \
  -- /bin/sh -c "
    trap 'kill 0 2>/dev/null; exit 0' TERM INT
    i=0
    while [ \"\$i\" -lt \"$WORKERS\" ]; do
      (while true; do wget -q -O- \"http://api/api/cpu?ms=$MS\" >/dev/null 2>&1 || true; done) &
      i=\$((i + 1))
    done
    wait
  "

kubectl wait --for=condition=Ready "pod/$POD_NAME" -n "$NS" --timeout=60s >/dev/null

printf '\033[32m==> Carga ativa! Acompanhe em outro terminal com: kubectl get hpa -n %s -w\033[0m\n' "$NS"

while true; do
  sleep 1
done
