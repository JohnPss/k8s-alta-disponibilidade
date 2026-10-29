#!/usr/bin/env bash
# Remove o namespace do projeto (ha-demo) e todos os seus recursos para reiniciar o ambiente do zero.
# Uso: ./scripts/reset.sh [-y] (opcional: NS=ha-demo ./scripts/reset.sh -y)

set -euo pipefail

NS="${NS:-ha-demo}"
if [[ "$NS" != "ha-demo" ]]; then
  echo "ERRO: O namespace suportado pelo projeto é estritamente 'ha-demo' (ver docs/CONTRATOS.md)." >&2
  exit 1
fi
AUTO_YES=false

if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
  AUTO_YES=true
fi

if [[ "$AUTO_YES" == false ]]; then
  read -r -p "Deseja realmente remover o namespace '$NS' e todos os seus recursos? [s/N] " resposta
  case "$resposta" in
    [sS]|[sS][iI][mM]|[yY]|[yY][eE][sS]) ;;
    *)
      echo "Operação cancelada."
      exit 0
      ;;
  esac
fi

echo "==> Removendo namespace '$NS'..."
kubectl delete ns "$NS" --wait=true --ignore-not-found=true
echo "==> Namespace '$NS' removido com sucesso."
