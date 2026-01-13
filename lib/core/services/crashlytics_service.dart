import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:injectable/injectable.dart';

/// Service for crash reporting and error tracking.
///
/// Wraps Firebase Crashlytics to provide a clean API for recording
/// errors, custom keys, and log messages.
@lazySingleton
class CrashlyticsService {
  final FirebaseCrashlytics _crashlytics;

  CrashlyticsService(this._crashlytics);

  /// Factory constructor for dependency injection
  @factoryMethod
  static CrashlyticsService create() {
    return CrashlyticsService(FirebaseCrashlytics.instance);
  }

  // ==================== Error Recording ====================

  /// Record a non-fatal error
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    await _crashlytics.recordError(
      exception,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }

  /// Record a Flutter error
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    await _crashlytics.recordFlutterFatalError(details);
  }

  // ==================== Custom Keys ====================

  /// Set user ID for crash reports
  Future<void> setUserId(String userId) async {
    await _crashlytics.setUserIdentifier(userId);
  }

  /// Clear user ID on sign out
  Future<void> clearUserId() async {
    await _crashlytics.setUserIdentifier('');
  }

  /// Set custom key-value pair for debugging
  Future<void> setCustomKey(String key, Object value) async {
    await _crashlytics.setCustomKey(key, value);
  }

  /// Set multiple custom keys at once
  Future<void> setCustomKeys(Map<String, Object> keys) async {
    for (final entry in keys.entries) {
      await _crashlytics.setCustomKey(entry.key, entry.value);
    }
  }

  // ==================== Context Keys ====================

  /// Set item count for crash context
  Future<void> setItemCount(int count) async {
    await setCustomKey('item_count', count);
  }

  /// Set device connection status
  Future<void> setDeviceConnected(bool connected) async {
    await setCustomKey('device_connected', connected);
  }

  /// Set current screen for crash context
  Future<void> setCurrentScreen(String screenName) async {
    await setCustomKey('current_screen', screenName);
  }

  /// Set last action for crash context
  Future<void> setLastAction(String action) async {
    await setCustomKey('last_action', action);
  }

  // ==================== Logging ====================

  /// Log a message for crash context
  Future<void> log(String message) async {
    await _crashlytics.log(message);
  }

  /// Log when entering a screen
  Future<void> logScreenEnter(String screenName) async {
    await log('Screen: $screenName');
    await setCurrentScreen(screenName);
  }

  /// Log when performing an action
  Future<void> logAction(String action) async {
    await log('Action: $action');
    await setLastAction(action);
  }

  /// Log Bluetooth operations
  Future<void> logBluetoothOperation(String operation) async {
    await log('Bluetooth: $operation');
  }

  /// Log Firestore operations
  Future<void> logFirestoreOperation(String operation) async {
    await log('Firestore: $operation');
  }

  // ==================== Test Crash ====================

  /// Force a crash for testing (use only in debug)
  void testCrash() {
    _crashlytics.crash();
  }

  // ==================== Collection Control ====================

  /// Enable or disable crash collection
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
  }

  /// Check if crash collection is enabled
  bool get isCrashlyticsCollectionEnabled =>
      _crashlytics.isCrashlyticsCollectionEnabled;
}
