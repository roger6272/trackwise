/// Bluetooth Low Energy (BLE) constants for ESP32 integration.
///
/// Contains UUIDs, MTU limits, timeouts, and other BLE-specific configuration.
/// These values match the ESP32 firmware implementation.
class BluetoothConstants {
  // Private constructor to prevent instantiation
  BluetoothConstants._();

  // ========== ESP32 BLE Service and Characteristics ==========

  /// Main BLE service UUID for Trackwise ESP32 device
  static const String serviceUUID = '12345678-1234-1234-1234-123456789000';

  /// Read characteristic UUID
  /// Used for: Reading data from ESP32
  static const String readCharacteristicUUID = '12345678-1234-1234-1234-123456789001';

  /// Notify characteristic UUID
  /// Used for: Receiving notifications from ESP32 (button presses, events)
  static const String notifyCharacteristicUUID = '12345678-1234-1234-1234-123456789002';

  /// Set Items characteristic UUID
  /// Used for: Sending the list of items to ESP32
  static const String setItemsCharacteristicUUID = '12345678-1234-1234-1234-123456789008';

  /// Write characteristic UUID
  /// Used for: Sending preferences and configuration to ESP32
  static const String writeCharacteristicUUID = '12345678-1234-1234-1234-123456789010';

  // ========== Message Chunking ==========

  /// Maximum Transmission Unit (MTU) limit for BLE messages
  /// ESP32 requires messages to be chunked to 180 bytes
  static const int mtuLimit = 180;

  /// Delay between message chunks in milliseconds
  /// ESP32 requires 30ms delay to process each chunk
  static const int chunkDelayMs = 30;

  /// Message delimiter (newline character)
  /// ESP32 uses newline to detect end of message
  static const int messageDelimiter = 10; // ASCII code for '\n'

  // ========== Timeouts ==========

  /// BLE device scan timeout in seconds
  static const int scanTimeoutSeconds = 15;

  /// BLE connection timeout in seconds
  static const int connectionTimeoutSeconds = 5;

  /// Characteristic read/write timeout in seconds
  static const int operationTimeoutSeconds = 3;

  // ========== Retry Configuration ==========

  /// Maximum number of connection retry attempts
  static const int maxConnectionRetries = 3;

  /// Delay between retry attempts in milliseconds
  static const int retryDelayMs = 1000;

  // ========== Message Types ==========

  /// JSON message types sent to/from ESP32
  static const String messageTypeItems = 'items';
  static const String messageTypePrefs = 'prefs';
  static const String messageTypeEvent = 'event';

  // ========== Device Identification ==========

  /// Device name prefix for filtering scan results
  /// ESP32 devices should start with this prefix
  static const String deviceNamePrefix = 'Trackwise';

  /// Minimum RSSI (signal strength) to consider device in range
  /// Values are negative; -100 is very weak, -30 is very strong
  static const int minimumRssi = -90;
}
