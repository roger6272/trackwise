/// Singleton state holder for BLE legacy operations.
///
/// Replaces FFAppState for the extracted BLE functions.
/// Holds pagination state for log syncing and selected item tracking.
class BleLegacyState {
  // Singleton instance
  static final BleLegacyState _instance = BleLegacyState._internal();
  factory BleLegacyState() => _instance;
  BleLegacyState._internal();

  /// Current page for paginated log reading from device.
  /// Incremented when device reports hasMore=true, reset to 0 when done.
  int currentLogPage = 0;

  /// Currently selected/activated item ID from device.
  /// Updated when device sends prefs data with selected_id.
  String? isactivated;
}
