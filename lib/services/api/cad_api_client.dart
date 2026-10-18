import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Result of a multi-view -> CadQuery generation call.
class CadResult {
  final String code;
  final bool mock;
  final int views;
  const CadResult({required this.code, required this.mock, required this.views});

  factory CadResult.fromJson(Map<String, dynamic> json) => CadResult(
        code: (json['code'] ?? '') as String,
        mock: (json['mock'] ?? false) as bool,
        views: (json['views'] ?? 0) as int,
      );
}

/// Backend health snapshot (mirrors GET /health).
class BackendHealth {
  final bool ok;
  final bool ready;
  final bool mock;
  final String model;
  final String device;
  const BackendHealth(
      {required this.ok, required this.ready, required this.mock,
       required this.model, required this.device});

  factory BackendHealth.fromJson(Map<String, dynamic> json) => BackendHealth(
        ok: (json['ok'] ?? false) as bool,
        ready: (json['ready'] ?? false) as bool,
        mock: (json['mock'] ?? false) as bool,
        model: (json['model'] ?? '') as String,
        device: (json['device'] ?? '') as String,
      );
}

/// HTTP client for the Phase-2 Zero-To-CAD backend.
///
/// Copies the resilience pattern from CupCake's ApiClient/OllamaEngine:
/// short connect timeout, long read timeout (VL decode takes 30-60s on
/// CPU), single in-flight generation at a time (server serializes anyway).
class CadApiClient {
  final Dio _dio;

  CadApiClient({String baseUrl = 'http://10.0.2.2:18765', Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(minutes: 6),
              sendTimeout: const Duration(minutes: 2),
            ));

  /// GET /health — liveness + model status.
  Future<BackendHealth> health() async {
    final res = await _dio.get('/health');
    return BackendHealth.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /load — warm the model (idempotent).
  Future<bool> load() async {
    final res = await _dio.post('/load');
    return (res.data['ok'] ?? false) as bool;
  }

  /// POST /generate-b64 — base64 views (works without file paths).
  ///
  /// [images] raw PNG/JPEG bytes per view (1-8). [labels] optional
  /// orthographic labels (front/top/side/iso/...) — server sorts them
  /// into canonical order so students can upload in any order.
  Future<CadResult> generate({
    required List<Uint8List> images,
    List<String>? labels,
    String? prompt,
    int maxNewTokens = 1024,
    double temperature = 0.2,
  }) async {
    final res = await _dio.post(
      '/generate-b64',
      data: {
        'images': images.map(base64Encode).toList(),
        if (labels != null) 'labels': labels,
        if (prompt != null) 'prompt': prompt,
        'max_new_tokens': maxNewTokens,
        'temperature': temperature,
      },
    );
    return CadResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /execute — sandboxed validation of generated code.
  Future<bool> execute(String code) async {
    final res = await _dio.post('/execute', data: {'code': code});
    return (res.data['ok'] ?? false) as bool;
  }
}
