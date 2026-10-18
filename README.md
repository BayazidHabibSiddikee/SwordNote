# SwordTrack

STEM Smart Notebook for engineering students — an infinite canvas where your handwritten notes come alive.

## What it does

- **Infinite canvas** with freehand pen/stylus input
- **Handwriting recognition** — on-device via GGUF model (llama.cpp JNI bridge, like CupCake)
- **Equations → Interactive graphs** — recognize math notation, plot instantly
- **Chemistry** — molecule names → 3D models, molecular structures
- **CAD generation** — sketch → parametric CAD (integrating ADSKAILab/Zero-To-CAD-Qwen3-VL-2B)
- **Contextual UI** — tools appear only when the AI detects STEM context

## Tech stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) + Riverpod |
| Canvas | `ink` package + custom viewport |
| On-device ML | llama.cpp via JNI (ARM64 NEON) — mirrors CupCake's `llama_jni` bridge |
| Backend (future) | FastAPI + RDKit + SymPy + Zero-To-CAD |

## Architecture

```
lib/
├── main.dart                    # App entry point (ProviderScope)
├── app.dart                     # MaterialApp + routing
├── core/
│   ├── theme/                   # Dark theme (engineering aesthetic)
│   └── utils/                   # Formatters, math helpers
├── features/
│   ├── canvas/                  # Infinite canvas + pen input
│   ├── math/                    # Equation recognition + graphing
│   ├── chemistry/               # Molecule lookup + rendering
│   └── cad/                     # CAD generation (Zero-To-CAD)
├── services/
│   ├── model/                   # NativeModelService (JNI bridge to llama.cpp)
│   └── api/                     # HTTP client for backend
├── providers/                   # Riverpod providers
└── ui/
    ├── screens/                 # HomeScreen, CanvasScreen, etc.
    └── widgets/                 # Reusable components
android/
└── app/src/main/cpp/
    └── swordtrack/              # JNI bridge mirroring CupCake's llama_jni.cpp
        ├── CMakeLists.txt
        └── swordtrack_jni.cpp
```

## Getting started

```bash
flutter pub get
flutter run
```

## Design philosophy

1. **Contextual activation** — tools appear only when AI detects STEM context
2. **Handwriting-first** — canvas feels like paper; typing is secondary
3. **Offline by default** — core features work without internet
4. **Freemium** — free tier for basic, subscription for advanced

## References

- CupCake (`../CupCake/`) — llama.cpp JNI bridge pattern, GGUF model loading
- ADSKAILab/Zero-To-CAD-Qwen3-VL-2B — sketch-to-CAD model
- pen2step (research) — hand-drawn → STEP, not yet production-ready
