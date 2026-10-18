import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Simple API client for backend services (Future Phase 2).
/// Currently a placeholder — no network calls are made in the initial build.
class ApiClient {
  static const String baseUrl = 'https://api.swordtrack.dev/v1';

  // TODO: Add dio client, auth headers, etc. when backend is ready.
  ApiClient();

  Future<String> recognizeMath(Uint8List image) async => throw UnimplementedError('Backend not ready');
  Future<String> lookupMolecule(String name) async => throw UnimplementedError('Backend not ready');
  Future<String> sketchToCad(List<String> views) async => throw UnimplementedError('Backend not ready');
}
