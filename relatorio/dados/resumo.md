# Resumo Consolidado dos Experimentos (Issue #28)

## Ambiente Experimental
- **Sistema Operacional (Host):** Ubuntu 24.04.4 LTS (Linux 6.14.0-33-generic, x86_64)
- **Orquestrador / Cluster:** Minikube v1.39.0 · Kubernetes v1.37.0 · containerd 2.3.4 · CNI Calico
- **Alocação do Cluster:** 1 nó (`minikube` / `ha-teste`), 4 vCPUs, 6144 MB RAM (4096 MB no perfil `ha-teste`)
- **Imagens em Cache Local:** `api:1.5`, `postgres:16-alpine`, `busybox:1.36` (`imagePullPolicy: IfNotPresent`)

---

## 1. Autorrecuperação / Self-Healing (`relatorio/dados/selfheal.csv`)
Procedimento: exclusão de 1 réplica ativa (`kubectl delete pod --wait=false`) com sondagem HTTP contínua a cada 100 ms (`scripts/measure-selfheal.sh 5`) até restabelecimento de 3/3 réplicas `Ready` distintas do pod removido.

| Execução | Tempo até 3/3 Ready (s) | Erros HTTP | Total de Requisições | Taxa de Sucesso (%) |
|---:|---:|---:|---:|---:|
| 1 | 5,96 | 0 | 34 | 100,00% |
| 2 | 5,84 | 1 | 34 | 97,06% |
| 3 | 8,84 | 0 | 40 | 100,00% |
| 4 | 8,83 | 0 | 37 | 100,00% |
| 5 | 8,38 | 0 | 37 | 100,00% |
| **Média ± DP (amostral)** | **7,57 ± 1,54 s** | **0,20 ± 0,45** | **36,40 ± 2,51** | **99,45% (181/182)** |

---

## 2. Escalabilidade Horizontal Manual 3 → 10 Réplicas (`relatorio/dados/scale.csv`)
Procedimento: disparo de `kubectl scale deployment api -n ha-demo --replicas=10` seguido de `kubectl rollout status deployment/api -n ha-demo` até `10/10 Ready`, retornando a 3 réplicas entre as rodadas.

| Execução | Tempo 3 → 10 Ready (s) |
|---:|---:|
| 1 | 7,16 |
| 2 | 6,58 |
| 3 | 6,82 |
| 4 | 6,80 |
| 5 | 6,75 |
| **Média ± DP (amostral)** | **6,82 ± 0,21 s** |

---

## 3. Persistência de Dados no PostgreSQL (`relatorio/dados/persistencia.csv`)
Procedimento: acúmulo de visitas em `/api/whoami`, leitura de `visits` antes, deleção forçada do pod `postgres-0`, verificação de resposta HTTP 200 degradada (`db: "indisponível"`) durante a queda, espera por `Ready` do novo `postgres-0` e nova consulta a `/api/whoami` comprovando `depois = antes + 1` sobre o mesmo PVC (`data-postgres-0`).

| Execução | Visitas Antes | Visitas Depois | Diferença (`depois - antes`) | Perda de Dados |
|---:|---:|---:|---:|---|
| 1 | 314 | 315 | +1 | 0 (100% preservado) |
| 2 | 260 | 261 | +1 | 0 (100% preservado) |
| 3 | 282 | 283 | +1 | 0 (100% preservado) |
| 4 | 502 | 503 | +1 | 0 (100% preservado) |
| 5 | 524 | 525 | +1 | 0 (100% preservado) |
