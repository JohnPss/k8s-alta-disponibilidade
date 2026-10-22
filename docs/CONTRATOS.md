# Contratos do projeto

> **Fonte única de nomes, portas e formatos.** Se todo mundo seguir este arquivo, cada um trabalha na sua parte **sem esperar ninguém**, e no final tudo se encaixa.
> Precisa mudar algo daqui? Abra um PR alterando este arquivo e marque o João Pedro. Não mude "só no seu código".

---

## 1. Nomes no Kubernetes

| Item | Valor |
|---|---|
| Namespace | `ha-demo` |
| Imagem da API | `api:1.3` (mudou o código? gere a próxima tag, `api:1.4`…, e atualize o Deployment e o `setup-cluster.sh`) |
| Deployment da API | `api` (label `app: api`, container `api`) |
| Service da API | `api`, tipo `NodePort`, `port: 80` → `targetPort: 8080`, `nodePort: 30080` |
| StatefulSet do banco | `postgres` (label `app: postgres`, container `postgres`) |
| Service do banco | `postgres`, headless (`clusterIP: None`), porta `5432` |
| PVC do banco | `volumeClaimTemplates` com nome `data`, então o PVC fica `data-postgres-0` (1Gi, RWO) |
| ConfigMap | `api-config` |
| Secret | `db-credentials` |
| NetworkPolicy | `postgres-allow-api` |
| HPA (extra) | `api` |

**URL da aplicação:** use sempre
```bash
URL=$(minikube service api -n ha-demo --url)
```
Funciona em Linux, Windows e Mac. O `http://$(minikube ip):30080` só funciona direto no Linux.

---

## 2. Variáveis de ambiente da API

| Variável | Origem | Exemplo | Valor padrão se ausente (rodando local) |
|---|---|---|---|
| `POD_NAME` | Downward API `metadata.name` | `api-7c9f-abc12` | hostname da máquina |
| `POD_IP` | Downward API `status.podIP` | `10.244.0.12` | `127.0.0.1` |
| `NODE_NAME` | Downward API `spec.nodeName` | `minikube` | `local` |
| `APP_VERSION` | ConfigMap | `1.0` | `dev` |
| `APP_MESSAGE` | ConfigMap | `Olá, turma de SO!` | `Olá!` |
| `APP_COLOR` | ConfigMap | `#2e86de` | `#2e86de` |
| `DB_HOST` | ConfigMap | `postgres` | `localhost` |
| `DB_PORT` | ConfigMap | `5432` | `5432` |
| `DB_NAME` | ConfigMap | `appdb` | `appdb` |
| `DB_USER` | Secret | `app` | `app` |
| `DB_PASSWORD` | Secret | `app123` (senha de demo) | `app123` |

O Postgres usa as **mesmas** chaves: `POSTGRES_USER` ← `DB_USER`, `POSTGRES_PASSWORD` ← `DB_PASSWORD` e `POSTGRES_DB` ← `DB_NAME`.

---

## 3. API HTTP (porta 8080)

Toda resposta leva o header **`Connection: close`**. Sem ele, o navegador reaproveita a conexão e fica preso num pod só.

| Método e rota | Resposta | Uso |
|---|---|---|
| `GET /` | HTML (página da demo) | Navegador |
| `GET /api/whoami` | JSON abaixo. **Registra 1 visita no banco** | Página, `traffic.sh`, medições |
| `GET /healthz` | `200 {"status":"ok"}`, ou `500 {"status":"unhealthy"}` se existir `/tmp/unhealthy` | livenessProbe |
| `GET /readyz` | `200 {"status":"ready"}` (**não** consulta o banco) | readinessProbe |
| `POST /api/crash` | `202 {"status":"crashing","pod":...}` e cria `/tmp/unhealthy` | Demo de liveness |
| `GET /api/cpu?ms=200` | `200 {"pod":...,"ms":200}` depois de gastar ~ms de CPU | Carga do HPA |

**JSON do `/api/whoami`:**
```json
{
  "pod": "api-7c9f-abc12",
  "pod_ip": "10.244.0.12",
  "node": "minikube",
  "version": "1.0",
  "message": "Olá, turma de SO!",
  "color": "#2e86de",
  "visits": 42,
  "db": "ok",
  "timestamp": "2026-10-20T14:03:11Z"
}
```
Banco fora do ar: `"visits": null` e `"db": "indisponível"`, **com status 200** (a API não cai).

**Mock para quem precisa antes da API existir:** salve o JSON acima como `mock/whoami.json` e sirva com `python3 -m http.server 8080`.

---

## 4. Banco de dados

```sql
CREATE TABLE IF NOT EXISTS visits (
  id  SERIAL PRIMARY KEY,
  pod TEXT NOT NULL,
  ts  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```
A API cria a tabela ao iniciar. O total de visitas é `SELECT count(*) FROM visits`.

**Postgres local para desenvolver sem o cluster:**
```bash
docker run -d --name pg-dev -p 5432:5432 -e POSTGRES_USER=app -e POSTGRES_PASSWORD=app123 -e POSTGRES_DB=appdb postgres:16-alpine
```

---

## 5. Recursos e probes (Deployment da API)

| Item | Valor |
|---|---|
| requests | `cpu: 100m`, `memory: 64Mi` |
| limits | `cpu: 250m`, `memory: 128Mi` |
| readinessProbe | `GET /readyz` `:8080`, `initialDelaySeconds: 2`, `periodSeconds: 3` |
| livenessProbe | `GET /healthz` `:8080`, `initialDelaySeconds: 5`, `periodSeconds: 5`, `failureThreshold: 3` |
| strategy | `RollingUpdate`, `maxSurge: 1`, `maxUnavailable: 0` |

---

## 6. Scripts (`scripts/`)

- Bash com `#!/usr/bin/env bash` e `set -euo pipefail`, executável (`chmod +x`).
- Namespace por variável: `NS=${NS:-ha-demo}`.
- Cada script começa com um comentário de 2 a 3 linhas dizendo o que faz e como usar.

| Script | Dono | O que faz |
|---|---|---|
| `setup-cluster.sh` | João Vitor | `minikube start` (calico, 4 CPU, 6 GB) + addon metrics-server + build da imagem |
| `deploy.sh` | Bernardo | `kubectl apply -f k8s/` + espera o rollout + imprime a URL |
| `traffic.sh` | João Vitor | Loop de `curl $URL/api/whoami` imprimindo `hora  pod  visitas` |
| `measure-selfheal.sh` | João Vitor | Deleta 1 pod, faz curl a cada 100 ms e grava o CSV |
| `reset.sh` | João Vitor | `kubectl delete ns ha-demo --wait` |
| `load-hpa.sh` | Ahmed | Gera carga em `/api/cpu` até Ctrl+C |

---

## 7. Evidências (prints e dados)

| Tipo | Onde salvar | Nome |
|---|---|---|
| Prints | `relatorio/figuras/` | `<issue>-<descricao>.png`, ex. `17-r5-selfheal-antes.png` |
| Dados de medição | `relatorio/dados/` | `selfheal.csv`, `scale.csv`, `persistencia.csv` |
| Logs | `relatorio/logs/` | `<issue>-<descricao>.txt` |

Formato dos CSVs:
- `selfheal.csv`: `execucao,segundos_ate_ready,erros_http,total_requisicoes`
- `scale.csv`: `execucao,segundos_3_para_10`
- `persistencia.csv`: `execucao,visitas_antes,visitas_depois`

---

## 8. Relatório LaTeX (`relatorio/`)

Cada seção fica num arquivo próprio. Assim ninguém edita o mesmo arquivo e não há conflito.

| Arquivo | Autor |
|---|---|
| `secoes/01-introducao.tex` | Thallys |
| `secoes/02-arquitetura.tex` | Luiz |
| `secoes/03-tecnologias.tex` | Bernardo (cada autor de código revisa sua parte) |
| `secoes/04-validacao.tex` | Lucas |
| `secoes/05-conclusao.tex` | Thallys |
| `secoes/06-repositorio.tex` | Luiz (link + tag) |

O PDF é compilado **automaticamente** pelo GitHub Actions a cada push (ver issue #11) e fica disponível na aba *Actions* → *Artifacts*.
