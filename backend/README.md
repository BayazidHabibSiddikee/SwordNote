# SwordNote Backend

Phase-2 server that serves the ADSKAILab/Zero-To-CAD-Qwen3-VL-2B model
for multi-view → CadQuery generation.

## Requirements

- Python 3.11+
- CUDA 12.x GPU with ≥16 GB VRAM (or Apple Silicon MPS)
- Git LFS (for model weights)

## Setup

```bash
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
```

## Run

```bash
# Start the FastAPI server (default port 18765)
uvicorn app:app --port 18765

# Or with custom port
uvicorn app:app --port 8080
```

## API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Liveness + model status |
| `/load` | POST | Warm the model (idempotent) |
| `/generate-b64` | POST | Multi-view images → CadQuery code |
| `/execute` | POST | Validate generated CadQuery code |

## Model

The backend loads `ADSKAILab/Zero-To-CAD-Qwen3-VL-2B` from HuggingFace.
First run will download ~4.2 GB.

```bash
export HF_ENDPOINT=https://hf-mirror.com  # optional: use mirror
uvicorn app:app --port 18765
```
