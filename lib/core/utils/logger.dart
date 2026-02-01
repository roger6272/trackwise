import 'package:flutter/foundation.dart';

/// Minimal app logger that only outputs in debug mode.
///
/// Replaces raw print()/debugPrint() calls to ensure zero logging
/// in production builds. All methods are no-ops when kDebugMode is false.
class AppLogger {
  AppLogger._();

  /// Debug-level log. Compiled out in release builds.
  static void debug(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// Error-level log. Compiled out in release builds.
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('ERROR: $message');
      if (error != null) debugPrint('  $error');
      if (stackTrace != null) debugPrint('  $stackTrace');
    }
  }
}
