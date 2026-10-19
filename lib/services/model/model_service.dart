import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'models.dart';

/// On-device model service — mirrors CupCake's LlamaEngine pattern.
///
/// Loads a GGUF model from app bundle, runs inference via JNI (C++ llama.cpp),
/// and exposes a simple `recognizeContent` API for the canvas feature.
///
/// In the initial build this is a **stub** that simulates recognition results.
/// The native bridge (`android/app/src/main/cpp/swordnote/`) is scaffolded
/// but not yet compiled — see the README for setup steps.
class ModelService {
  static const _kModelFileName = 'qwen2.5-0.5b-q4_0.gguf';

  bool _loaded = false;
  String? _errorMessage;

  /// Copy the bundled GGUF model from assets to the app's files dir.
  Future<File> _copyModelFromAssets() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models');
    await modelDir.create(recursive: true);
    final modelFile = File('${modelDir.path}/$_kModelFileName');

    if (modelFile.existsSync() && modelFile.lengthSync() > 1_000_000) {
      debugPrint('ModelService: model already exists (${modelFile.lengthSync()} bytes)');
      return modelFile;
    }

    debugPrint('ModelService: copying model from assets…');
    final data = await rootBundle.load('assets/models/$_kModelFileName');
    await modelFile.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    debugPrint('ModelService: model copied (${modelFile.lengthSync()} bytes)');
    return modelFile;
  }

  /// Check if the bundled model file exists and is valid (4-byte GGUF magic).
  Future<bool> _isValidGguf(File file) async {
    if (!file.existsSync() || file.lengthSync() < 8) return false;
    final bytes = await file.readAsBytes();
    return bytes.length >= 4 &&
        bytes[0] == 0x47 && bytes[1] == 0x47 &&
        bytes[2] == 0x55 && bytes[3] == 0x46; // 'GGUF'
  }

  /// Load the model into native memory. Returns true on success.
  Future<bool> load() async {
    if (_loaded) return true;

    // TODO: Remove this stub once the native bridge is linked.
    // _loaded = Platform.isAndroid;
    // return _loaded;

    // Stub: pretend ready so the UI can be tested without native code
    _loaded = true;
    return true;
  }

  /// Check if model is loaded and ready.
  Future<bool> isModelReady() async => _loaded;

  /// Get last error message, if any.
  String? get errorMessage => _errorMessage;

  /// Recognize STEM content from an image.
  /// Returns a [RecognitionResult] with extracted text and optional chart data.
  Future<RecognitionResult> recognizeContent(Uint8List imageBytes) async {
    if (!_loaded) {
      return const RecognitionResult(text: '(model not loaded)');
    }

    // TODO: Replace with actual JNI call once native bridge is wired up.
    // The native signature mirrors CupCake's LlamaEngine.generateStream().
    //
    // 1. Convert imageBytes → Base64 or save to temp file
    // 2. Call native `analyzeImage(imagePath)` which:
    //    a. Feeds image to Qwen2.5-VL via llama.cpp
    //    b. Returns structured JSON with recognized text + optional math/chem/CAD
    // 3. Parse JSON → RecognitionResult
    //
    // Example expected response structure:
    // {
    //   "text": "∫ x² dx = x³/3 + C",
    //   "type": "math",
    //   "latex": "x^2",
    //   "context": "calculus"
    // }

    // Simulated result for UI development
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return const RecognitionResult(
      text: '∫ x² dx → (plot this to see the graph)',
    );
  }

  /// Release native model resources.
  void unload() {
    // TODO: Call native releaseModel() once bridge is linked
    _loaded = false;
  }
}
