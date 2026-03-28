import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:injectable/injectable.dart';

/// Service for tracking analytics events and user properties.
///
/// Wraps Firebase Analytics to provide a clean API for tracking
/// user behavior throughout the app.
@lazySingleton
class AnalyticsService {
  final FirebaseAnalytics _analytics;

  AnalyticsService(this._analytics);

  /// Factory constructor for dependency injection
  @factoryMethod
  static AnalyticsService create() {
    return AnalyticsService(FirebaseAnalytics.instance);
  }

  // ==================== Item Events ====================

  /// Track when a user creates a new item
  Future<void> logItemCreated({
    required String itemId,
    required String itemName,
  }) async {
    await _analytics.logEvent(
      name: 'item_created',
      parameters: {
        'item_id': itemId,
        'item_name': itemName,
      },
    );
  }

  /// Track when a user updates an item
  Future<void> logItemUpdated({
    required String itemId,
  }) async {
    await _analytics.logEvent(
      name: 'item_updated',
      parameters: {'item_id': itemId},
    );
  }

  /// Track when a user deletes an item
  Future<void> logItemDeleted({
    required String itemId,
  }) async {
    await _analytics.logEvent(
      name: 'item_deleted',
      parameters: {'item_id': itemId},
    );
  }

  /// Track when a user increments an item count
  Future<void> logItemIncremented({
    required String itemId,
    required int increment,
  }) async {
    await _analytics.logEvent(
      name: 'item_incremented',
      parameters: {
        'item_id': itemId,
        'increment': increment,
      },
    );
  }

  // ==================== Device Events ====================

  /// Track when Bluetooth device is connected
  Future<void> logDeviceConnected({
    required String deviceId,
    required String deviceName,
  }) async {
    await _analytics.logEvent(
      name: 'device_connected',
      parameters: {
        'device_id': deviceId,
        'device_name': deviceName,
      },
    );
  }

  /// Track when Bluetooth device is disconnected
  Future<void> logDeviceDisconnected({
    required String deviceId,
  }) async {
    await _analytics.logEvent(
      name: 'device_disconnected',
      parameters: {'device_id': deviceId},
    );
  }

  /// Track when items are sent to device
  Future<void> logItemsSentToDevice({
    required int itemCount,
  }) async {
    await _analytics.logEvent(
      name: 'items_sent_to_device',
      parameters: {'item_count': itemCount},
    );
  }

  // ==================== Export Events ====================

  /// Track when user exports data as CSV
  Future<void> logCsvExported({
    required String aggregationLevel,
    required int eventCount,
  }) async {
    await _analytics.logEvent(
      name: 'csv_exported',
      parameters: {
        'aggregation_level': aggregationLevel,
        'event_count': eventCount,
      },
    );
  }

  /// Track when user exports data as JSON (GDPR)
  Future<void> logDataExported() async {
    await _analytics.logEvent(name: 'data_exported');
  }

  // ==================== Account Events ====================

  /// Track when user signs up
  Future<void> logSignUp({
    required String method,
  }) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  /// Track when user signs in
  Future<void> logLogin({
    required String method,
  }) async {
    await _analytics.logLogin(loginMethod: method);
  }

  /// Track when user signs out
  Future<void> logSignOut() async {
    await _analytics.logEvent(name: 'sign_out');
  }

  /// Track when user deletes account (GDPR)
  Future<void> logAccountDeleted() async {
    await _analytics.logEvent(name: 'account_deleted');
  }

  // ==================== User Properties ====================

  /// Set the number of items the user has
  Future<void> setItemCount(int count) async {
    await _analytics.setUserProperty(
      name: 'item_count',
      value: count.toString(),
    );
  }

  /// Set whether user has connected a device
  Future<void> setHasConnectedDevice(bool hasDevice) async {
    await _analytics.setUserProperty(
      name: 'has_connected_device',
      value: hasDevice.toString(),
    );
  }

  /// Set the firmware version of the connected device
  Future<void> setFirmwareVersion(String version) async {
    await _analytics.setUserProperty(
      name: 'firmware_version',
      value: version,
    );
  }

  /// Set the user's signup method
  Future<void> setSignupMethod(String method) async {
    await _analytics.setUserProperty(
      name: 'signup_method',
      value: method,
    );
  }

  /// Set user ID for analytics
  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  // ==================== Screen Tracking ====================

  /// Log current screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  // ==================== Navigation Events ====================

  /// Track navigation to a specific feature
  Future<void> logFeatureUsed({
    required String featureName,
  }) async {
    await _analytics.logEvent(
      name: 'feature_used',
      parameters: {'feature_name': featureName},
    );
  }

  // ==================== OTA Events ====================

  /// Track when an OTA firmware update starts downloading
  Future<void> logOtaStarted({
    required String fromVersion,
    required String toVersion,
  }) async {
    await _analytics.logEvent(
      name: 'ota_started',
      parameters: {
        'from_version': fromVersion,
        'to_version': toVersion,
      },
    );
  }

  /// Track when an OTA firmware update completes successfully
  Future<void> logOtaCompleted({
    required String fromVersion,
    required String toVersion,
    required int durationSeconds,
  }) async {
    await _analytics.logEvent(
      name: 'ota_completed',
      parameters: {
        'from_version': fromVersion,
        'to_version': toVersion,
        'duration_seconds': durationSeconds,
      },
    );
  }

  /// Track when an OTA firmware update fails
  Future<void> logOtaFailed({
    required String reason,
    required String fromVersion,
    required String toVersion,
  }) async {
    await _analytics.logEvent(
      name: 'ota_failed',
      parameters: {
        'reason': reason.substring(
          0,
          reason.length > 100 ? 100 : reason.length,
        ),
        'from_version': fromVersion,
        'to_version': toVersion,
      },
    );
  }

  /// Track when the user cancels an OTA firmware update
  Future<void> logOtaCancelled({
    required String fromVersion,
    required String toVersion,
    required double progressPercent,
  }) async {
    await _analytics.logEvent(
      name: 'ota_cancelled',
      parameters: {
        'from_version': fromVersion,
        'to_version': toVersion,
        'progress_percent': progressPercent,
      },
    );
  }

  // ==================== Error Events ====================

  /// Track non-fatal errors for analytics
  Future<void> logError({
    required String errorType,
    required String errorMessage,
  }) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 100 ? 100 : errorMessage.length,
        ),
      },
    );
  }
}
