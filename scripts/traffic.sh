#!/usr/bin/env bash
# Envia requisições contínuas para /api/whoami e exibe horário, pod e total de visitas.
# Uso: ./scripts/traffic.sh (opcional: NS=ha-demo URL=http://... INTERVAL=0.3 ./scripts/traffic.sh)

set -euo pipefail

export LC_NUMERIC=C

NS="${NS:-ha-demo}"
if [[ "$NS" != "ha-demo" ]]; then
  echo "ERRO: O namespace suportado pelo projeto é estritamente 'ha-demo' (ver docs/CONTRATOS.md)." >&2
  exit 1
fi
URL="${URL:-$(minikube service api -n "$NS" --url)}"
INTERVAL="${INTERVAL:-0.3}"

printf 'Enviando tráfego para %s/api/whoami (intervalo: %ss) — Ctrl+C para parar\n' "${URL%/}" "$INTERVAL"
printf '%-8s  %-28s  %s\n' "HORA" "POD" "VISITAS"

while true; do
  agora="$(date +%H:%M:%S)"
  # AUD-01: -m 3 (3s) para permitir o fallback da API caso o banco caia (timeout do banco na API = 2s)
  if resposta="$(curl -s -f -m 3 "${URL%/}/api/whoami" 2>/dev/null)" && [[ -n "$resposta" ]]; then
    if command -v jq >/dev/null 2>&1; then
      pod="$(printf '%s' "$resposta" | jq -r '.pod // "?"')"
      visitas="$(printf '%s' "$resposta" | jq -r 'if .visits == null then "indisponível" else (.visits | tostring) end')"
    else
      pod="$(printf '%s' "$resposta" | sed -n 's/.*"pod":[[:space:]]*"\([^"]*\)".*/\1/p')"
      visitas="$(printf '%s' "$resposta" | sed -n 's/.*"visits":[[:space:]]*\([0-9null]*\).*/\1/p')"
    fi
    printf '%s  %-28s  %s\n' "$agora" "$pod" "$visitas"
  else
    printf '%s  \033[31mFALHA\033[0m\n' "$agora"
  fi
  sleep "$INTERVAL"
done
