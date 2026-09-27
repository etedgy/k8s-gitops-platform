"""
Minimal demo web service for the DevOps assignment.

Endpoints:
  GET /            -> greeting + pod metadata (proves which replica served you)
  GET /healthz     -> liveness probe  (is the process alive?)
  GET /readyz      -> readiness probe (should we send it traffic?)
  GET /metrics     -> Prometheus metrics
  GET /work        -> burns CPU for a bit; handy for demoing the HPA

The app deliberately separates liveness from readiness:
  * liveness  fails  -> kubelet restarts the container
  * readiness fails  -> pod is pulled from the Service endpoints but NOT killed
Readiness can be toggled at runtime (POST /toggle-ready) to demo rolling
traffic-shifting and to reproduce "pod Ready flapping" style incidents.
"""
import os
import time
import threading

from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# --- identity / config (all injected via env, never baked into the image) ---
POD_NAME = os.getenv("POD_NAME", "local")
NODE_NAME = os.getenv("NODE_NAME", "local")
APP_ENV = os.getenv("APP_ENV", "dev")
APP_VERSION = os.getenv("APP_VERSION", "dev")

# Readiness starts true; can be flipped to simulate an unready pod.
_ready = threading.Event()
_ready.set()

# --- metrics ---
REQUESTS = Counter(
    "app_requests_total", "Total HTTP requests", ["method", "path", "status"]
)
LATENCY = Histogram(
    "app_request_latency_seconds", "Request latency in seconds", ["path"]
)


@app.after_request
def _observe(resp):
    REQUESTS.labels(request.method, request.path, resp.status_code).inc()
    return resp


@app.route("/")
def index():
    with LATENCY.labels("/").time():
        return jsonify(
            message="Hello from the DevOps assignment app",
            env=APP_ENV,
            version=APP_VERSION,
            pod=POD_NAME,
            node=NODE_NAME,
        )


@app.route("/healthz")
def healthz():
    # Liveness: the process can serve requests. Keep this cheap and dependency-free
    # so a slow dependency never triggers a restart storm.
    return jsonify(status="ok"), 200


@app.route("/readyz")
def readyz():
    # Readiness: only report ready when we should receive traffic. In a real app
    # this would also check downstream dependencies (DB, cache) with short timeouts.
    if _ready.is_set():
        return jsonify(status="ready"), 200
    return jsonify(status="not-ready"), 503


@app.route("/toggle-ready", methods=["POST"])
def toggle_ready():
    if _ready.is_set():
        _ready.clear()
    else:
        _ready.set()
    return jsonify(ready=_ready.is_set())


@app.route("/work")
def work():
    # Busy-loop for ~`ms` milliseconds to generate CPU load for the HPA demo.
    ms = min(int(request.args.get("ms", 200)), 5000)
    deadline = time.time() + ms / 1000.0
    x = 0
    while time.time() < deadline:
        x += 1
    return jsonify(iterations=x, burned_ms=ms)


@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    # Dev server only. Production serves via gunicorn (see Dockerfile CMD).
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 8080)))
