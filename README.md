# Kubernetes: Orquestração Avançada e Alta Disponibilidade

Trabalho prático de **Sistemas Operacionais Modernos** (Prof. Michel Pires da Silva, CEFET-MG / DECOM).
**Grupo G3, Tema 5 (Prática 5).**

Integrantes: João Pedro, João Vitor, Ahmed, Bernardo, Luiz, Hugo, Lucas, Thallys.

## Objetivo
Subir num cluster Kubernetes local (Minikube) uma API web com 3 réplicas exposta por Service NodePort, com PostgreSQL persistente, e demonstrar ao vivo **self-healing** (`kubectl delete pod`) e **escalabilidade** (`kubectl scale --replicas=10`).

## Documentos
- [Plano completo](docs/PLANO.md): decisões de arquitetura, metodologia e checklist de conformidade
- [Cronograma](docs/CRONOGRAMA.md): fluxo das fases e Gantt
- **Kanban / Roadmap:** aba *Projects* deste repositório

## Estrutura
```
app/        API Flask + Dockerfile
k8s/        manifestos aplicados com kubectl apply -f k8s/
extras/     HPA (aplicar só após a validação obrigatória)
scripts/    setup, deploy, tráfego, medições, reset
docs/       plano, cronograma, roteiro da demo, diagramas
relatorio/  relatório LaTeX
```

## Como rodar
> Em construção. Ver issues da milestone *S1 · Setup*.

## Datas
- Entrega: **21/11/2026**
- Apresentação: **23/11/2026**
