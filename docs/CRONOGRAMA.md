# Cronograma

Linha do tempo do trabalho (Prática 5, Kubernetes). A fonte da verdade do andamento é o **Project (Board/Roadmap)**; este arquivo mostra a visão geral.

## Fluxo das fases

```mermaid
flowchart LR
    S1["S1 · Setup<br/>28/09–04/10"] --> S2["S2 · Aplicação<br/>05/10–11/10"]
    S2 --> S3["S3 · Marco M2<br/>12/10–18/10<br/>obrigatório pronto"]
    S3 --> S4["S4 · Estado e config<br/>19/10–25/10"]
    S4 --> S5["S5 · Rede e extras<br/>26/10–01/11"]
    S3 -. prints R4/R5/R6 .-> S6
    S5 --> S6["S6 · Evidências e relatório<br/>02/11–08/11"]
    S6 --> S7["S7 · Ensaios + vídeo<br/>09/11–15/11"]
    S7 --> S8["S8 · Entrega<br/>21/11"]
    S8 --> AP(["Apresentação<br/>23/11"])
    style S3 fill:#2ecc71,color:#000
    style S8 fill:#e67e22,color:#000
    style AP fill:#e74c3c,color:#fff
```

## Linha do tempo (Gantt)

Barras vermelhas: caminho crítico do obrigatório (marco M2).

```mermaid
gantt
    title Cronograma G3 · Tema 5 (Kubernetes)
    dateFormat YYYY-MM-DD
    axisFormat %d/%m
    todayMarker stroke-width:3px,stroke:#e74c3c
    section S1 · Setup
    Criar repositório e estrutura de pastas :done, 2026-09-28, 2026-09-29
    Instalar ambiente (8 integrantes) :2026-09-28, 2026-10-05
    Script setup-cluster.sh e registro de versões :2026-09-30, 2026-10-05
    Esqueleto do relatório LaTeX (6 seções) :2026-09-30, 2026-10-05
    section S2 · Aplicação
    API Flask base (/, /api/whoami, /healthz, /readyz) :2026-10-05, 2026-10-10
    Página HTML com auto-refresh e cor do ConfigMap :2026-10-07, 2026-10-12
    Dockerfile e build da imagem no Minikube :2026-10-08, 2026-10-12
    section S3 · Marco M2 (obrigatório)
    Manifestos base - Namespace, Deployment (replicas - 3), Service NodePort :crit, 2026-10-12, 2026-10-16
    Script deploy.sh :crit, 2026-10-12, 2026-10-15
    Marco M2 - validar R4, R5 e R6 e primeiros prints :crit, 2026-10-15, 2026-10-19
    section S4 · Estado e configuração
    ConfigMap e Secret :2026-10-19, 2026-10-22
    Postgres - Service headless + StatefulSet + PVC :2026-10-19, 2026-10-23
    Integrar API com o banco (tabela visits) :2026-10-20, 2026-10-25
    Deployment completo - initContainer, envFrom, probes, resources :2026-10-22, 2026-10-26
    section S5 · Rede e extras
    Teste de persistência (deletar postgres-0) :2026-10-26, 2026-10-28
    NetworkPolicy e teste do pod intruso :2026-10-26, 2026-10-29
    Endpoints /api/crash e /api/cpu :2026-10-26, 2026-10-29
    HPA em extras/ e script load-hpa.sh :2026-10-28, 2026-11-01
    Scripts traffic.sh, measure-selfheal.sh e reset.sh :2026-10-26, 2026-10-31
    Pré-carregar imagens para demo offline :2026-10-30, 2026-11-02
    section S6 · Evidências e relatório
    Experimentos 5× e tabelas de medições :2026-11-02, 2026-11-07
    Diagrama final da arquitetura :2026-11-02, 2026-11-05
    Redigir seções 1–5 do relatório :2026-11-02, 2026-11-08
    Revisão cruzada do relatório :2026-11-08, 2026-11-09
    section S7 · Ensaios
    Roteiro da demo final (docs/ROTEIRO-DEMO.md) :2026-11-09, 2026-11-11
    Ensaio geral 1 + arguição simulada :2026-11-11, 2026-11-12
    Gravar vídeo sem cortes (plano B) :2026-11-12, 2026-11-14
    Ensaio geral 2 com rodízio no terminal :2026-11-14, 2026-11-16
    section S8 · Entrega
    Revisão final e compilação do relatório :2026-11-16, 2026-11-20
    Tag v1.0 e congelar o repositório :2026-11-19, 2026-11-21
    Entrega do trabalho (21/11) :2026-11-21, 2026-11-22
    section Apresentação
    Preparar notebook da apresentação :2026-11-22, 2026-11-23
    Apresentação - live demo (23/11) :2026-11-23, 2026-11-24
    section Marcos
    M2 - obrigatório pronto :milestone, crit, 2026-10-18, 0d
    Entrega (21/11) :milestone, crit, 2026-11-21, 0d
    Apresentação (23/11) :milestone, crit, 2026-11-23, 0d
```

## Marcos (milestones)

| Milestone | Prazo | Objetivo |
|---|---|---|
| S1 · Setup | 04/10 | Repositório, ambiente de todos e esqueleto do relatório. |
| S2 · Aplicação | 11/10 | API Flask, página HTML e imagem Docker. |
| S3 · Marco M2 (obrigatório) | 18/10 | Deployment + Service no ar e validação R4/R5/R6 ok. |
| S4 · Estado e configuração | 25/10 | Postgres com PVC, ConfigMap/Secret, dependência e probes. |
| S5 · Rede e extras | 01/11 | NetworkPolicy, HPA, endpoints extras, scripts e demo offline. |
| S6 · Evidências e relatório | 08/11 | Medições, diagrama e redação do relatório. |
| S7 · Ensaios | 15/11 | Roteiro final, ensaios e vídeo plano B. |
| S8 · Entrega | 21/11 | Revisão final, tag v1.0 e entrega (21/11). |
| Apresentação | 23/11 | Preparação do notebook e live demo (23/11). |

> Detalhes de cada tarefa: issues do repositório e `docs/PLANO.md` §9.
