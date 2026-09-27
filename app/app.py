"""Minimal demo web service for the DevOps assignment."""
import os
import time
import threading

from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

POD_NAME = os.getenv("POD_NAME", "local")
NODE_NAME = os.getenv("NODE_NAME", "local")
APP_ENV = os.getenv("APP_ENV", "dev")
APP_VERSION = os.getenv("APP_VERSION", "dev")

_ready = threading.Event()
_ready.set()

REQUESTS = Counter("app_requests_total", "Total HTTP requests", ["method", "path", "status"])
LATENCY = Histogram("app_request_latency_seconds", "Request latency in seconds", ["path"])


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
    # Liveness: cheap and dependency-free so a slow dependency can't cause restarts.
    return jsonify(status="ok"), 200


@app.route("/readyz")
def readyz():
    # Readiness: gates traffic; would also check downstream deps in a real app.
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
    # Burns CPU to demo the HPA.
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
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 8080)))
