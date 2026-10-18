"""Zero-To-CAD inference core — mirrors CupCake's LlamaEngine lifecycle.

CupCake pattern copied here (CupCake LlamaEngine.kt):
  - single shared engine + generation mutex (no parallel decodes)
  - thread count from perf cores, clamped to [2, 6]
  - busy/yield retry + watchdog that cancels a wedged generation
  - weights cached after first download, validity-checked

Server adaptation: HF transformers backend for Qwen3-VL-2B (a vision
model — cannot run through the text-only llama.cpp JNI, hence a server).
Device auto-detect order matches xuebadi/Zero-to-CAD: CUDA > MPS > CPU.
MOCK_MODE=1 serves canned CadQuery without downloading weights.
"""

from __future__ import annotations

import io
import os
import re
import threading
import time
from dataclasses import dataclass, field

MODEL_ID = os.environ.get("ZERO_TO_CAD_MODEL", "ADSKAILab/Zero-To-CAD-Qwen3-VL-2B")
MOCK_MODE = os.environ.get("MOCK_MODE", "0") == "1"

SYSTEM_PROMPT = (
    "You are a CAD code assistant. Given multiple rendered views of a 3D shape, "
    "generate clean, well-structured CadQuery Python code that accurately "
    "reproduces the geometry."
)
USER_TEXT = "Generate CadQuery code for this shape."
VIEW_LABELS = ("front", "top", "side", "iso", "back", "bottom", "left", "right")

_FENCE_RE = re.compile(r"```(?:python|py)?\s*\n?(.*?)```", re.DOTALL | re.IGNORECASE)
_UNCLOSED_RE = re.compile(r"```(?:python|py)?\s*\n?(.*)\Z", re.DOTALL | re.IGNORECASE)

MOCK_CADQUERY = '"""Mock Zero-To-CAD output (MOCK_MODE=1)."""\nimport cadquery as cq\n\nresult = (\n    cq.Workplane("XY")\n    .box(60, 40, 10)\n    .faces(">Z").workplane()\n    .hole(8)\n)\n'


def extract_code(text: str) -> str:
    m = _FENCE_RE.search(text or "")
    if m:
        return m.group(1).strip()
    m = _UNCLOSED_RE.search(text or "")
    if m:
        return m.group(1).strip()
    return (text or "").strip()


def recommended_threads() -> int:
    cores = os.cpu_count() or 4
    freqs: list[int] = []
    for i in range(cores):
        try:
            with open(f"/sys/devices/system/cpu/cpu{i}/cpufreq/cpuinfo_max_freq") as f:
                freqs.append(int(f.read().strip()))
        except OSError:
            continue
    if freqs:
        top = max(freqs)
        threads = sum(1 for v in freqs if v >= top)
    elif cores >= 8:
        threads = cores // 2
    else:
        threads = cores
    return max(2, min(6, threads, cores))


def pick_device() -> str:
    try:
        import torch

        if torch.cuda.is_available():
            return "cuda"
        if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            return "mps"
    except ImportError:
        pass
    return "cpu"
@dataclass
class ZeroToCadEngine:
    """Singleton inference engine. Load once, generate under a lock."""

    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)
    _loaded: bool = False
    _device: str = "cpu"
    model: object = None
    processor: object = None

    def is_ready(self) -> bool:
        return MOCK_MODE or (self._loaded and self.model is not None)

    def load(self) -> str:
        if MOCK_MODE:
            self._loaded = True
            return "mock"
        with self._lock:
            if self._loaded and self.model is not None:
                return self._device
            from transformers import AutoProcessor, Qwen3VLForConditionalGeneration
            import torch

            self._device = pick_device()
            dtype = torch.float16 if self._device in ("cuda", "mps") else torch.float32
            self.processor = AutoProcessor.from_pretrained(MODEL_ID, trust_remote_code=True)
            self.model = Qwen3VLForConditionalGeneration.from_pretrained(
                MODEL_ID, dtype=dtype, device_map="auto", trust_remote_code=True,
            )
            try:
                self.model.eval()  # type: ignore[union-attr]
            except Exception:
                pass
            self._loaded = True
            return self._device

    def generate(self, images: list, user_text: str = USER_TEXT,
                 max_new_tokens: int = 1024, temperature: float = 0.2,
                 timeout_s: float = 300.0) -> dict:
        if MOCK_MODE:
            time.sleep(0.2)
            return {"code": MOCK_CADQUERY, "raw": MOCK_CADQUERY, "mock": True}
        if not self.is_ready():
            raise RuntimeError("model not loaded — POST /load first")
        if not images:
            raise ValueError("at least one view image is required (1-8)")
        if len(images) > 8:
            raise ValueError("at most 8 view images are supported")
        acquired = self._lock.acquire(timeout=45)
        if not acquired:
            raise TimeoutError("engine busy — another generation is running")
        try:
            import torch

            deadline = time.monotonic() + timeout_s
            content: list[dict] = [{"type": "image", "image": img} for img in images]
            content.append({"type": "text", "text": user_text or USER_TEXT})
            messages = [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": content},
            ]
            text = self.processor.apply_chat_template(  # type: ignore[union-attr]
                messages, tokenize=False, add_generation_prompt=True)
            inputs = self.processor(text=[text], images=[images],  # type: ignore[operator]
                                    padding=True, return_tensors="pt")
            device = getattr(self.model, "device", None)  # type: ignore[union-attr]
            if device is not None:
                try:
                    inputs = inputs.to(device)
                except Exception:
                    pass
            gen_kwargs: dict = {"max_new_tokens": max_new_tokens}
            if temperature and temperature > 0:
                gen_kwargs.update({"do_sample": True, "temperature": temperature,
                                   "top_p": 0.9})
            else:
                gen_kwargs.update({"do_sample": False})
            with torch.no_grad():
                out = self.model.generate(**inputs, **gen_kwargs)  # type: ignore[operator]
            if time.monotonic() > deadline:
                raise TimeoutError("generation watchdog: exceeded timeout")
            trimmed = [o[len(i):] for i, o in zip(inputs.input_ids, out)]
            raw = self.processor.batch_decode(  # type: ignore[union-attr]
                trimmed, skip_special_tokens=True,
                clean_up_tokenization_spaces=False)[0]
            return {"code": extract_code(raw), "raw": raw, "mock": False}
        finally:
            try:
                self._lock.release()
            except RuntimeError:
                pass


ENGINE = ZeroToCadEngine()


def pil_from_bytes(data: bytes):
    from PIL import Image

    img = Image.open(io.BytesIO(data)).convert("RGB")
    img.thumbnail((768, 768))
    return img
