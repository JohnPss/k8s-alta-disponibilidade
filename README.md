# Kubernetes: Orquestração Avançada e Alta Disponibilidade

Trabalho prático de **Sistemas Operacionais Modernos** (Prof. Michel Pires da Silva, CEFET-MG / DECOM).
**Grupo G3, Tema 5 (Prática 5).**

Integrantes: João Pedro, João Vitor, Ahmed, Bernardo, Luiz, Hugo, Lucas, Thallys.

## Objetivo
Subir num cluster Kubernetes local (Minikube) uma API web com 3 réplicas exposta por Service NodePort, com PostgreSQL persistente, e demonstrar ao vivo **self-healing** (`kubectl delete pod`) e **escalabilidade** (`kubectl scale --replicas=10`).

## Documentos
- [Plano completo](docs/PLANO.md): decisões de arquitetura, metodologia e checklist de conformidade
- [Cronograma](docs/CRONOGRAMA.md): fluxo das fases e Gantt
- [Contratos](docs/CONTRATOS.md): nomes, portas, variáveis e formatos que todos seguem
- [Fluxo de trabalho](docs/FLUXO.md): como pegar uma tarefa, abrir PR, quem revisa quem
- [Kanban e linha do tempo (GitHub Project)](https://github.com/users/JohnPss/projects/1)

## Estrutura
```
app/        API Flask + Dockerfile
k8s/        manifestos aplicados com kubectl apply -f k8s/
extras/     HPA (aplicar só após a validação obrigatória)
scripts/    setup, deploy, tráfego, medições, reset
docs/       plano, cronograma, contratos, fluxo de trabalho
relatorio/  relatório LaTeX
```

## Versões
| Ferramenta / Imagem | Versão |
|---|---|
| Minikube | v1.39.0 |
| Kubernetes (servidor) | v1.37.0 |
| kubectl | v1.37.1 |
| Docker | 29.1.3 |
| Python | 3.12 |
| PostgreSQL | 16-alpine |
| Imagem da API | Conforme [CONTRATOS.md](docs/CONTRATOS.md) (fonte única de tag) |

## Como rodar

```bash
# 1. Iniciar o cluster Minikube, habilitar addons e compilar a imagem da API
# (O script compila a tag indicada em docs/CONTRATOS.md; para build manual use a tag definida lá)
./scripts/setup-cluster.sh

# 2. Aplicar todos os manifestos Kubernetes e exibir a URL do Service
./scripts/deploy.sh

# 3. Gerar tráfego contínuo mostrando qual pod respondeu e o total de visitas
./scripts/traffic.sh

# 4. Medir o tempo de self-healing (N execuções) e salvar em relatorio/dados/selfheal.csv
./scripts/measure-selfheal.sh 5

# 5. (Opcional) Testar auto-scaling horizontal (HPA) e gerador de carga
kubectl apply -f extras/50-hpa.yaml
./scripts/load-hpa.sh

# 6. Remover o namespace ha-demo para reiniciar o ambiente do zero (-y pula confirmação)
./scripts/reset.sh -y
```

## Demo offline

Para garantir que a apresentação funcione em ambientes sem acesso à internet ou com Wi-Fi instável, todas as imagens necessárias são mantidas em cache local no Minikube e os manifestos utilizam `imagePullPolicy: IfNotPresent`:

| Imagem | Origem | Finalidade |
|---|---|---|
| `api:1.6` | Build local (`minikube image build`) | Imagem da API Flask com 3 réplicas |
| `postgres:16-alpine` | Pré-carregada (`minikube image pull`) | Banco de dados persistente (StatefulSet) |
| `busybox:1.36` | Pré-carregada (`minikube image pull`) | InitContainer de espera do banco (`wait-for-postgres`) e carga do HPA (`load-hpa.sh`) |

O pré-carregamento é realizado automaticamente pelo passo 7 do `./scripts/setup-cluster.sh`.

### Conferindo as imagens em cache

```bash
minikube image ls
```

As imagens `docker.io/library/api:1.6`, `docker.io/library/postgres:16-alpine` e `docker.io/library/busybox:1.36` devem constar na listagem.

### Resultado do teste real sem internet

O isolamento offline foi testado e validado bloqueando o tráfego externo dentro do nó Minikube via `iptables` (mantendo apenas redes internas do cluster) e comprovando a falha de conexão com registros externos (`curl -sS -m 5 https://registry-1.docker.io/v2/`).

Sob essas condições:
1. `./scripts/reset.sh -y && ./scripts/deploy.sh` recriou todos os recursos e todos os pods (`postgres-0` e réplicas da `api`) atingiram `1/1 Running / Ready` sem nenhum evento de `ImagePullBackOff`.
2. `./scripts/load-hpa.sh` subiu o pod `load` com `busybox:1.36` diretamente do cache local, alcançando `Ready` de forma instantânea.
3. Ao término, as regras de firewall foram removidas e a conectividade com a internet foi restaurada com sucesso.

O registro completo da execução real está em [`relatorio/logs/27-offline.txt`](relatorio/logs/27-offline.txt).

## Datas
- Entrega: **21/11/2026**
- Apresentação: **23/11/2026**
