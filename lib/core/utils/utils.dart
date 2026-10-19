import 'dart:async';

/// Common utility functions.
abstract class AppUtils {
  /// Format a number to a human-readable string.
  static String formatNumber(double num) {
    if (num.abs() >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num.abs() >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return num.toStringAsFixed(2);
  }

  /// Truncate text with ellipsis.
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }

  /// Debounce a function call.
  static Timer? _debounceTimer;
  static void debounce(void Function() fn, [Duration duration = const Duration(milliseconds: 300)]) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, fn);
  }
}
