/// Application-wide constants.
///
/// Contains configuration values, limits, and defaults used across the app.
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // App Info
  static const String appName = 'Trackwise';
  static const String appVersion = '1.0.0';

  // Item Constraints
  static const int maxItemNameLength = 30;
  static const int minIncrementValue = 1;
  static const int maxIncrementValue = 100;
  static const int minReminderValue = 0;
  static const int maxReminderValue = 1000;

  // Firestore Collections
  static const String itemsCollection = 'Item';
  static const String eventLogCollection = 'EventLog';
  static const String usersCollection = 'users';
  static const String mailCollection = 'mail';

  // Firestore Field Names (matching existing schema)
  static const String itemNameField = 'item_name';
  static const String countField = 'count';
  static const String todayCountField = 'todaycount';
  static const String incrementByField = 'increment_by';
  static const String reminderField = 'reminder';
  static const String reminderValueField = 'reminder_value';
  static const String lastResetTimeField = 'lastResetTime';
  static const String lastUpdatedField = 'lastUpdated';
  static const String userIdField = 'user_id';
  static const String createdTimeField = 'created_time';
  static const String eventNameField = 'event_name';
  static const String itemIdField = 'item_id';

  // Date/Time Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String timeFormat = 'HH:mm:ss';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';

  // CSV Export
  static const String csvDateFormat = 'yyyy-MM-dd';
  static const String csvFileNamePrefix = 'tally_export';

  // Cache Keys
  static const String cachedItemsKey = 'CACHED_ITEMS';
  static const String cachedUserKey = 'CACHED_USER';

  // Error Messages
  static const String networkErrorMessage = 'Network error. Please check your connection.';
  static const String serverErrorMessage = 'Server error. Please try again later.';
  static const String bluetoothErrorMessage = 'Bluetooth error. Please check your connection.';
  static const String authErrorMessage = 'Authentication error. Please sign in again.';
  static const String unknownErrorMessage = 'An unknown error occurred.';

  // Timeouts (milliseconds)
  static const int networkTimeout = 30000; // 30 seconds
  static const int cacheTimeout = 300000; // 5 minutes

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
}
