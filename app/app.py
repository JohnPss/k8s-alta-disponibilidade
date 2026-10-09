"""API Flask da demo de alta disponibilidade.

Issue #12: rotas do contrato, ainda sem banco.
/api/whoami responde com visits=null e db="indisponível".
A integração com o Postgres fica para a #20.

Issue #24: POST /api/crash marca o pod como doente e GET /api/cpu gasta CPU.
"""

import hashlib
import os
import socket
import time
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, jsonify, render_template, request

app = Flask(__name__)
app.json.sort_keys = False
app.json.ensure_ascii = False

UNHEALTHY_FILE = Path("/tmp/unhealthy")
CPU_DEFAULT_MS = 200
CPU_MAX_MS = 2000


def settings():
    """Variáveis de CONTRATOS §2, com o padrão de quando a API roda local."""
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
    payload = {
        "pod": cfg["pod"],
        "pod_ip": cfg["pod_ip"],
        "node": cfg["node"],
        "version": cfg["version"],
        "message": cfg["message"],
        "color": cfg["color"],
        "visits": None,
        "db": "indisponível",
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
    """Cria /tmp/unhealthy. O /healthz passa a 500 e a liveness reinicia o container."""
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
