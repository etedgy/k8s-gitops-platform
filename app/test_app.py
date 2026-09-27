"""Tiny smoke tests so CI has something real to run before building the image."""
import app as appmod


def _client():
    appmod.app.testing = True
    return appmod.app.test_client()


def test_index_ok():
    r = _client().get("/")
    assert r.status_code == 200
    assert r.get_json()["message"].startswith("Hello")


def test_healthz_ok():
    r = _client().get("/healthz")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"


def test_readyz_toggles():
    c = _client()
    assert c.get("/readyz").status_code == 200
    assert c.post("/toggle-ready").get_json()["ready"] is False
    assert c.get("/readyz").status_code == 503
    c.post("/toggle-ready")  # restore
    assert c.get("/readyz").status_code == 200


def test_metrics_exposed():
    r = _client().get("/metrics")
    assert r.status_code == 200
    assert b"app_requests_total" in r.data
