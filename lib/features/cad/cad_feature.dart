import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/cad_api_client.dart';

/// Provider for the Phase-2 CAD backend client.
final cadApiClientProvider = Provider<CadApiClient>((ref) => CadApiClient());

/// CAD feature: multi-view drawing photos -> editable CadQuery code.
///
/// Niche: engineering students photograph orthographic projections from
/// technical-drawing class (front / top / side / iso / ...) and get back
/// runnable CadQuery they can edit — via the FastAPI backend in
/// `backend/` serving ADSKAILab/Zero-To-CAD-Qwen3-VL-2B.
///
/// Reference: https://github.com/xuebadi/Zero-to-CAD
class CadFeature {
  final CadApiClient _api;
  CadFeature(this._api);

  /// Convert 1-8 view photos to CadQuery code.
  ///
  /// [views] raw image bytes per view; [labels] optional orthographic
  /// labels in matching order (e.g. ['front','top','side']).
  /// Returns null when the backend is unreachable or rejects the input.
  Future<String?> sketchToCad(
    List<Uint8List> views, {
    List<String>? labels,
    String? prompt,
  }) async {
    if (views.isEmpty || views.length > 8) return null;
    try {
      final result = await _api.generate(
        images: views,
        labels: labels,
        prompt: prompt,
      );
      return result.code.isEmpty ? null : result.code;
    } catch (_) {
      return null;
    }
  }

  /// Check if the current stroke context looks like an engineering sketch.
  static bool isEngineeringContext(String recognition) {
    const engTerms = {
      'dimension', 'tolerance', 'surface finish', 'datum',
      'geometric tolerance', 'profile', 'concentricity', 'parallelism',
    };
    return engTerms.any((term) => recognition.toLowerCase().contains(term));
  }
}

/// Riverpod accessor for the CAD feature.
final cadFeatureProvider = Provider<CadFeature>(
  (ref) => CadFeature(ref.watch(cadApiClientProvider)),
);

