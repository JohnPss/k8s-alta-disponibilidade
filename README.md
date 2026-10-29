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

## Datas
- Entrega: **21/11/2026**
- Apresentação: **23/11/2026**
