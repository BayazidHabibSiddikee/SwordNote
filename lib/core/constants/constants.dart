/// Common constants used across the app.
abstract class AppConstants {
  static const String appName = 'SwordNote';
  static const String appVersion = '1.0.0';
  static const int maxStrokePoints = 1000;
  static const double minStrokeLength = 5.0;
  static const Duration animationDuration = Duration(milliseconds: 200);

  // Model config
  static const String defaultModelName = 'qwen2.5-0.5b-q4_0.gguf';
  static const int defaultNctx = 2048;
  static const int defaultNthreads = 4;
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 512;
}
