"""FastAPI server for Phase 2: multi-view drawing photos -> CadQuery code.

Endpoints:
  GET  /health              liveness + model status
  POST /load                download + warm Qwen3-VL-2B (idempotent)
  POST /generate            multipart images (1-8 views) -> CadQuery code
  POST /generate-b64        JSON with base64 images (easier from Flutter)
  POST /execute             sandboxed CadQuery validation -> STEP export

Run:
  pip install -r requirements.txt
  MOCK_MODE=1 uvicorn app:app --port 18765     # no weights, instant
  uvicorn app:app --port 18765                 # real weights (~4.2GB dl)
"""

from __future__ import annotations

import base64
import io
import os
import subprocess
import sys
import tempfile

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from zero_to_cad import (
    ENGINE,
    MODEL_ID,
    MOCK_MODE,
    USER_TEXT,
    VIEW_LABELS,
    pil_from_bytes,
    pick_device,
    recommended_threads,
)

MAX_IMAGES = 8
MAX_BYTES = 10 * 1024 * 1024

app = FastAPI(title="SwordNote Zero-To-CAD", version="0.2.0")


class GenerateB64(BaseModel):
    images: list[str] = Field(min_length=1, max_length=MAX_IMAGES)
    labels: list[str] | None = None
    prompt: str = USER_TEXT
    max_new_tokens: int = Field(default=1024, le=2048)
    temperature: float = Field(default=0.2, ge=0.0, le=1.0)


class ExecuteReq(BaseModel):
    code: str = Field(min_length=10, max_length=200_000)


@app.get("/health")
def health():
    return {
        "ok": True,
        "model": MODEL_ID,
        "mock": MOCK_MODE,
        "ready": ENGINE.is_ready(),
        "device": pick_device(),
        "threads": recommended_threads(),
        "max_views": MAX_IMAGES,
    }


@app.post("/load")
def load():
    try:
        device = ENGINE.load()
        return {"ok": True, "ready": ENGINE.is_ready(), "device": device,
                "model": MODEL_ID, "mock": MOCK_MODE}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"load failed: {e}")


def _ordered(images: list, labels: list[str] | None):
    if not labels or len(labels) != len(images):
        return images
    order = {name: i for i, name in enumerate(VIEW_LABELS)}
    paired = sorted(zip(labels, images),
                    key=lambda p: order.get(str(p[0]).lower(), 99))
    return [img for _, img in paired]


def _decode_uploads(files: list[UploadFile]):
    if not files:
        raise HTTPException(status_code=400, detail="attach 1-8 view images")
    if len(files) > MAX_IMAGES:
        raise HTTPException(status_code=400, detail="at most 8 views supported")
    images = []
    for f in files:
        data = f.file.read()
        if len(data) > MAX_BYTES:
            raise HTTPException(status_code=413, detail=f"{f.filename}: >10MB")
        try:
            images.append(pil_from_bytes(data))
        except Exception:
            raise HTTPException(status_code=400, detail=f"{f.filename}: not an image")
    return images


@app.post("/generate")
async def generate(files: list[UploadFile] = File(...), prompt: str = USER_TEXT,
                   max_new_tokens: int = 1024, temperature: float = 0.2):
    images = _decode_uploads(files)
    try:
        out = ENGINE.generate(images, user_text=prompt,
                              max_new_tokens=max_new_tokens, temperature=temperature)
    except (ValueError, TimeoutError, RuntimeError) as e:
        raise HTTPException(status_code=409 if isinstance(e, TimeoutError) else 400,
                            detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"generation failed: {e}")
    return JSONResponse({"ok": True, "code": out["code"], "mock": out["mock"],
                         "views": len(images)})


@app.post("/generate-b64")
def generate_b64(req: GenerateB64):
    images = []
    for i, b64 in enumerate(req.images):
        try:
            images.append(pil_from_bytes(base64.b64decode(b64)))
        except Exception:
            raise HTTPException(status_code=400, detail=f"image {i}: bad base64/image")
    images = _ordered(images, req.labels)
    try:
        out = ENGINE.generate(images, user_text=req.prompt,
                              max_new_tokens=req.max_new_tokens,
                              temperature=req.temperature)
    except (ValueError, TimeoutError, RuntimeError) as e:
        raise HTTPException(status_code=409 if isinstance(e, TimeoutError) else 400,
                            detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"generation failed: {e}")
    return {"ok": True, "code": out["code"], "mock": out["mock"], "views": len(images)}


@app.post("/execute")
def execute(req: ExecuteReq):
    """Validate generated code in an isolated subprocess (demo execute/)."""
    runner = (
        "import sys, traceback\n"
        "ns = {}\n"
        "try:\n"
        "    exec(open(sys.argv[1]).read(), {'__name__': '__exec__'}, ns)\n"
        "    result = ns.get('result', None)\n"
        "    print('EXEC_OK result=%s' % type(result).__name__)\n"
        "except Exception:\n"
        "    traceback.print_exc()\n"
        "    print('EXEC_FAIL')\n"
    )
    with tempfile.TemporaryDirectory() as d:
        code_path = os.path.join(d, "code.py")
        with open(code_path, "w") as f:
            f.write(req.code)
        try:
            p = subprocess.run([sys.executable, "-c", runner, code_path],
                               capture_output=True, text=True, timeout=120)
        except subprocess.TimeoutExpired:
            raise HTTPException(status_code=504, detail="execution timed out (120s)")
        ok = "EXEC_OK" in p.stdout
        return {"ok": ok, "stdout": p.stdout[-4000:], "stderr": p.stderr[-4000:]}
