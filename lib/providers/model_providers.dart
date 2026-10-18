import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/model/model_service.dart';

/// Provider for the on-device model service (singleton).
final modelServiceProvider = Provider<ModelService>((ref) {
  return ModelService();
});

/// Async provider that loads the model on first access.
final modelServiceLoadedProvider = FutureProvider.autoDispose.family<bool, String>((ref, key) async {
  final service = ref.watch(modelServiceProvider);
  return service.load();
});
