#!/usr/bin/env bash
# Inicializa e configura o cluster Minikube para o trabalho de Alta Disponibilidade (K8s).
# Configura o driver Docker, CNI Calico, recursos (4 CPUs, 6GB RAM),
# ativa o metrics-server e compila a imagem local da API se o Dockerfile existir.
#
# Uso: ./scripts/setup-cluster.sh

set -euo pipefail

cd "$(dirname "$0")/.."

CPUS="${CPUS:-4}"
MEMORY="${MEMORY:-6144}"
DRIVER="${DRIVER:-docker}"
CNI="${CNI:-calico}"
NS="${NS:-ha-demo}"

echo "==> 1. Verificando pré-requisitos locais..."
command -v docker >/dev/null 2>&1 || { echo "ERRO: Docker não está instalado."; exit 1; }
command -v minikube >/dev/null 2>&1 || { echo "ERRO: Minikube não está instalado."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERRO: Kubectl não está instalado."; exit 1; }

echo "==> 2. Iniciando cluster Minikube (Driver: $DRIVER, CNI: $CNI, CPUs: $CPUS, RAM: ${MEMORY}MB)..."
minikube start \
  --driver="$DRIVER" \
  --cni="$CNI" \
  --cpus="$CPUS" \
  --memory="$MEMORY"

echo "==> 3. Habilitando addon metrics-server..."
minikube addons enable metrics-server

echo "==> 4. Aguardando o nó ficar Ready..."
kubectl wait --for=condition=Ready node/minikube --timeout=120s

echo "==> 5. Verificando/Criando namespace $NS..."
if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
  kubectl create namespace "$NS"
  echo "Namespace '$NS' criado com sucesso."
else
  echo "Namespace '$NS' já existe."
fi

echo "==> 6. Compilação da imagem da API..."
if [[ -f "app/Dockerfile" ]]; then
  echo "Dockerfile encontrado. Construindo imagem api:1.0 no Minikube..."
  minikube image build -t api:1.0 ./app
  echo "Imagem api:1.0 construída com sucesso."
else
  echo "Aviso: app/Dockerfile ainda não existe (será adicionado na issue #14). Pulando build da imagem."
fi

echo ""
echo "=========================================================="
echo "Cluster Minikube configurado e pronto para o trabalho!"
echo "=========================================================="
kubectl get nodes -o wide
echo ""
echo "Pod do metrics-server e componentes:"
kubectl get pods -n kube-system -l k8s-app=metrics-server
