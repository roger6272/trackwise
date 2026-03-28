/// Bluetooth Low Energy (BLE) constants for ESP32 integration.
///
/// Contains UUIDs, MTU limits, timeouts, and other BLE-specific configuration.
/// These values match the ESP32 firmware implementation.
class BluetoothConstants {
  // Private constructor to prevent instantiation
  BluetoothConstants._();

  // ========== ESP32 BLE Service and Characteristics ==========

  /// Main BLE service UUID for Traxelos ESP32 device
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

  /// OTA Data characteristic UUID
  /// Used for: Sending firmware update data to ESP32 (optional, firmware v2+)
  static const String otaDataCharacteristicUUID = '12345678-1234-1234-1234-123456789011';

  // ========== Standard Battery Service ==========

  /// Battery Service UUID (standard BLE 0x180F in 128-bit format)
  /// Optional — only present on firmware that supports battery reporting
  static const String batteryServiceUUID = '0000180f-0000-1000-8000-00805f9b34fb';

  /// Battery Level characteristic UUID (standard BLE 0x2A19 in 128-bit format)
  /// Reports battery percentage (0-100) via notify
  static const String batteryLevelCharacteristicUUID = '00002a19-0000-1000-8000-00805f9b34fb';

  // ========== Message Chunking ==========

  /// Default MTU limit for BLE messages (fallback if negotiation fails)
  static const int defaultMtuLimit = 180;

  /// Requested MTU size during negotiation
  /// Android supports up to 517, iOS up to 185
  static const int requestedMtu = 512;

  /// ATT protocol overhead (subtract from negotiated MTU for payload size)
  static const int attOverhead = 3;

  /// Delay between message chunks in milliseconds
  /// ESP32 requires 20ms delay to process each chunk
  static const int chunkDelayMs = 20;

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

  // ========== Connection Delays ==========

  /// Delay after stopping scan before connecting (prevents Android error 133)
  static const int scanStopDelayMs = 2000;

  /// Delay after connection before initial sync (let BLE stabilize)
  static const int connectionStabilizeDelayMs = 300;

  /// Delay between BLE commands during initial sync
  static const int commandIntervalDelayMs = 100;

  /// Delay after prepare_read write before reading (ESP32 processing time)
  static const int prepareReadDelayMs = 500;

  /// Maximum number of log pages to request before giving up.
  /// Prevents infinite pagination if firmware always reports hasMore=true.
  /// 50 pages × 15 entries/page = 750 log entries max.
  static const int maxLogPages = 50;

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
  static const String deviceNamePrefix = 'Traxelos_One';

  /// Minimum RSSI (signal strength) to consider device in range
  /// Values are negative; -100 is very weak, -30 is very strong
  static const int minimumRssi = -90;
}
