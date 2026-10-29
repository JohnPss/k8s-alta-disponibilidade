"""API Flask da demo de alta disponibilidade.

Issue #20: /api/whoami grava uma visita no Postgres e devolve o total.
Se o banco cair, a resposta continua 200 com db="indisponível".
O /readyz não consulta o banco.

Issue #24: POST /api/crash marca o pod como doente e GET /api/cpu gasta CPU.
"""

import hashlib
import os
import socket
import time
from datetime import datetime, timezone
from pathlib import Path

import psycopg
from flask import Flask, jsonify, render_template, request

app = Flask(__name__)
app.json.sort_keys = False
app.json.ensure_ascii = False

UNHEALTHY_FILE = Path("/tmp/unhealthy")
CPU_DEFAULT_MS = 200
CPU_MAX_MS = 2000
# AUD-01: connect_timeout em segundos. O valor mínimo aceito pela libpq é 2s.
# Os clientes (index.html e traffic.sh com timeout de 3s) aguardam o tempo necessário
# para que a API capture a exceção e devolva o fallback HTTP 200 (db="indisponível").
DB_CONNECT_TIMEOUT = 2

# AUD-05: Flag para assegurar que o DDL (CREATE TABLE) execute no máximo uma vez
# por processo, evitando contenção em pg_catalog sob tráfego simultâneo.
_table_ensured = False

CREATE_VISITS = """
CREATE TABLE IF NOT EXISTS visits (
  id  SERIAL PRIMARY KEY,
  pod TEXT NOT NULL,
  ts  TIMESTAMPTZ NOT NULL DEFAULT now()
)
"""


def settings():
    return {
        "pod": os.getenv("POD_NAME", socket.gethostname()),
        "pod_ip": os.getenv("POD_IP", "127.0.0.1"),
        "node": os.getenv("NODE_NAME", "local"),
        "version": os.getenv("APP_VERSION", "dev"),
        "message": os.getenv("APP_MESSAGE", "Olá!"),
        "color": os.getenv("APP_COLOR", "#2e86de"),
        "db_host": os.getenv("DB_HOST", "localhost"),
        "db_port": os.getenv("DB_PORT", "5432"),
        "db_name": os.getenv("DB_NAME", "appdb"),
        "db_user": os.getenv("DB_USER", "app"),
        "db_password": os.getenv("DB_PASSWORD", "app123"),
    }


app.config.update(settings())


# AUD-06: Optou-se por conexão direta por requisição em vez de psycopg_pool.
# O Gunicorn roda com múltiplos workers (-w 2 --threads 2), onde pools exigiriam
# cuidados com fork/socket sharing e dependência extra (psycopg_pool). A conexão
# direta mantém o pod estritamente stateless, seguro pós-fork e garante recuperação
# graciosa imediata se o pod do Postgres for reiniciado na demonstração ao vivo.
def connect_db():
    cfg = settings()
    return psycopg.connect(
        host=cfg["db_host"],
        port=cfg["db_port"],
        dbname=cfg["db_name"],
        user=cfg["db_user"],
        password=cfg["db_password"],
        connect_timeout=DB_CONNECT_TIMEOUT,
    )


def ensure_visits_table(conn):
    with conn.cursor() as cur:
        cur.execute(CREATE_VISITS)


def init_db():
    global _table_ensured
    try:
        with connect_db() as conn:
            ensure_visits_table(conn)
            _table_ensured = True
    except Exception:
        return


def record_visit(pod):
    global _table_ensured
    try:
        with connect_db() as conn:
            with conn.cursor() as cur:
                # Se o banco subiu após a API, cria a tabela na primeira requisição com sucesso
                if not _table_ensured:
                    cur.execute(CREATE_VISITS)
                    _table_ensured = True
                cur.execute("INSERT INTO visits (pod) VALUES (%s)", (pod,))
                cur.execute("SELECT count(*) FROM visits")
                (count,) = cur.fetchone()
            return int(count)
    except Exception:
        return None


init_db()


@app.after_request
def close_connection(response):
    response.headers["Connection"] = "close"
    return response


@app.get("/")
def index():
    cfg = settings()
    return render_template(
        "index.html",
        pod=cfg["pod"],
        pod_ip=cfg["pod_ip"],
        node=cfg["node"],
        version=cfg["version"],
        message=cfg["message"],
        color=cfg["color"],
    )


@app.get("/api/whoami")
def whoami():
    cfg = settings()
    visits = record_visit(cfg["pod"])
    payload = {
        "pod": cfg["pod"],
        "pod_ip": cfg["pod_ip"],
        "node": cfg["node"],
        "version": cfg["version"],
        "message": cfg["message"],
        "color": cfg["color"],
        "visits": visits,
        "db": "ok" if visits is not None else "indisponível",
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    return jsonify(payload)


@app.get("/healthz")
def healthz():
    if UNHEALTHY_FILE.exists():
        return jsonify({"status": "unhealthy"}), 500
    return jsonify({"status": "ok"})


@app.get("/readyz")
def readyz():
    return jsonify({"status": "ready"})


@app.post("/api/crash")
def crash():
    UNHEALTHY_FILE.touch()
    return jsonify({"status": "crashing", "pod": settings()["pod"]}), 202


def cpu_milliseconds():
    raw = request.args.get("ms", str(CPU_DEFAULT_MS))
    try:
        ms = int(raw)
    except (TypeError, ValueError):
        ms = CPU_DEFAULT_MS
    return max(0, min(ms, CPU_MAX_MS))


def burn_cpu(ms):
    deadline = time.perf_counter() + ms / 1000
    payload = b"ha-demo"
    while time.perf_counter() < deadline:
        payload = hashlib.sha256(payload).digest()


@app.get("/api/cpu")
def cpu():
    ms = cpu_milliseconds()
    burn_cpu(ms)
    return jsonify({"pod": settings()["pod"], "ms": ms})
