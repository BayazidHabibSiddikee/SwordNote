"""Smoke tests for the Phase-2 backend (run against MOCK_MODE=1 server)."""

import base64
import io
import os

import pytest
import httpx
from PIL import Image

BASE = os.environ.get("ZERO_TO_CAD_URL", "http://127.0.0.1:18765")


def _png(color=(120, 120, 200)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (160, 160), color).save(buf, format="PNG")
    return buf.getvalue()


def test_health():
    r = httpx.get(f"{BASE}/health", timeout=10)
    assert r.status_code == 200
    body = r.json()
    assert body["ok"] is True
    assert body["max_views"] == 8


def test_generate_multipart():
    files = [("files", (f"view_{i}.png", _png(), "image/png")) for i in range(3)]
    r = httpx.post(f"{BASE}/generate", files=files, timeout=120)
    assert r.status_code == 200
    body = r.json()
    assert body["ok"] is True
    assert "cadquery" in body["code"].lower() or "cq" in body["code"]
    assert body["views"] == 3


def test_generate_b64_ordering():
    imgs = [base64.b64encode(_png((i * 50 % 255, 100, 150))).decode() for i in range(2)]
    r = httpx.post(f"{BASE}/generate-b64",
                   json={"images": imgs, "labels": ["side", "front"]}, timeout=120)
    assert r.status_code == 200
    assert r.json()["views"] == 2


def test_generate_rejects_empty():
    r = httpx.post(f"{BASE}/generate-b64", json={"images": []}, timeout=30)
    assert r.status_code == 422


def test_execute_sandbox():
    code = "result = 42\n"
    r = httpx.post(f"{BASE}/execute", json={"code": code}, timeout=150)
    assert r.status_code == 200
    assert r.json()["ok"] is True


@pytest.mark.skipif(os.environ.get("MOCK_MODE", "1") == "1",
                    reason="live-model only: checks real weights path")
def test_live_model_ready():
    r = httpx.get(f"{BASE}/health", timeout=10)
    assert r.json()["ready"] is True
    assert r.json()["mock"] is False
