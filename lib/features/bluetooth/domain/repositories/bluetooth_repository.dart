import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../items/domain/entities/item.dart';
import '../entities/ble_connection_state.dart';
import '../entities/ble_device.dart';
import '../entities/ble_message.dart';
import '../entities/sync_state.dart';

/// Repository interface for Bluetooth operations.
///
/// Defines the contract for BLE communication with ESP32 devices.
/// The data layer implements this interface using flutter_blue_plus.
///
/// All methods return Either<Failure, T> for type-safe error handling:
/// - Left(BluetoothFailure): BLE operation failed
/// - Right(T): Operation succeeded with result
///
/// Stream-returning methods emit Either values for real-time updates.
abstract class BluetoothRepository {
  // ============================================================
  // SCANNING
  // ============================================================

  /// Scans for nearby BLE devices.
  ///
  /// Emits updated device list as devices are discovered.
  /// Stream completes when [timeout] expires or [stopScan] is called.
  ///
  /// Filters to only show devices with non-empty names.
  ///
  /// Returns stream of:
  /// - Right(List<BleDevice>): Currently discovered devices
  /// - Left(BluetoothFailure): Scan failed (permissions, adapter off, etc.)
  Stream<Either<Failure, List<BleDevice>>> scanDevices({
    Duration timeout = const Duration(seconds: 15),
  });

  /// Stops an active scan.
  ///
  /// Returns:
  /// - Right(void): Scan stopped successfully
  /// - Left(BluetoothFailure): Failed to stop scan
  Future<Either<Failure, void>> stopScan();

  // ============================================================
  // CONNECTION
  // ============================================================

  /// Connects to a BLE device by ID.
  ///
  /// Discovers services and validates that required characteristics exist:
  /// - SET_ITEMS characteristic (12345678-1234-1234-1234-123456789008)
  /// - WRITE characteristic (12345678-1234-1234-1234-123456789010)
  ///
  /// Returns:
  /// - Right(true): Connected and device has required characteristics
  /// - Right(false): Connected but missing required characteristics
  /// - Left(BluetoothFailure): Connection failed (timeout, device unavailable, etc.)
  Future<Either<Failure, bool>> connect(String deviceId);

  /// Disconnects from a device.
  ///
  /// Sets manual disconnect flag to prevent auto-reconnection.
  /// Cancels any active BLE listeners for this device.
  ///
  /// Returns:
  /// - Right(void): Disconnected successfully
  /// - Left(BluetoothFailure): Disconnect failed
  Future<Either<Failure, void>> disconnect(String deviceId);

  /// Gets the currently connected device, if any.
  ///
  /// Returns:
  /// - Right(BleDevice): Currently connected device
  /// - Right(null): No device connected
  /// - Left(BluetoothFailure): Failed to check connection status
  Future<Either<Failure, BleDevice?>> getConnectedDevice();

  /// Watches connection state changes for a device.
  ///
  /// Emits new state whenever connection status changes.
  /// Used for auto-reconnect logic and UI updates.
  ///
  /// Returns stream of:
  /// - Right(BleConnectionState): Current connection state
  /// - Left(BluetoothFailure): Failed to monitor connection
  Stream<Either<Failure, BleConnectionState>> watchConnectionState(
    String deviceId,
  );

  // ============================================================
  // COMMANDS (Write to ESP32)
  // ============================================================

  /// Sends the item list to ESP32 device.
  ///
  /// Formats items as JSON array with fields:
  /// id, name, count, todaycount, increment, reminder, reminder_value, lastResetTime, category
  ///
  /// [categoryNames] maps categoryId -> categoryName for resolving display names.
  ///
  /// Handles 180-byte MTU chunking with 30ms delay between chunks.
  /// Writes to SET_ITEMS characteristic (12345678-1234-1234-1234-123456789008).
  ///
  /// Returns:
  /// - Right(void): Items sent successfully
  /// - Left(BluetoothFailure): Send failed (not connected, write error, etc.)
  Future<Either<Failure, void>> sendItems(
    String deviceId,
    List<Item> items, {
    Map<String, String> categoryNames = const {},
  });

  /// Sends selected item command to ESP32.
  ///
  /// Sends JSON: {"cmd": "set_selected", "id": deviceItemId}
  /// The deviceItemId is a numeric ID (0-99) used for BLE communication.
  /// Writes to WRITE characteristic (12345678-1234-1234-1234-123456789010).
  ///
  /// Returns:
  /// - Right(void): Command sent successfully
  /// - Left(BluetoothFailure): Send failed
  Future<Either<Failure, void>> sendSelectedItem(
    String deviceId,
    int deviceItemId,
  );

  /// Syncs device clock with current time.
  ///
  /// Sends JSON: {"cmd": "set_time", "utc_time": "yyyy-MM-dd HH:mm:ss", "offset": minutes}
  /// Writes to WRITE characteristic.
  ///
  /// Returns:
  /// - Right(void): Time synced successfully
  /// - Left(BluetoothFailure): Sync failed
  Future<Either<Failure, void>> sendTimeSync(String deviceId);

  /// Requests data from device (prefs or logs).
  ///
  /// Sends JSON: {"cmd": "prepare_read", "type": type, "page": page}
  /// Response will arrive via NOTIFY characteristic (watchMessages stream).
  /// - type "prefs": Request item status updates
  /// - type "logs": Request historical event logs
  ///
  /// Returns:
  /// - Right(void): Command sent successfully
  /// - Left(BluetoothFailure): Request failed
  Future<Either<Failure, void>> requestData(
    String deviceId,
    String type,
    int page,
  );

  /// Clears logs on the ESP32 device.
  ///
  /// Sends JSON: {"cmd": "clear_logs"}
  /// Called after all log pages have been retrieved.
  ///
  /// Returns:
  /// - Right(void): Clear command sent successfully
  /// - Left(BluetoothFailure): Command failed
  Future<Either<Failure, void>> clearLogs(String deviceId);

  /// Deletes an item on the ESP32 device by device item ID.
  ///
  /// Sends JSON: {"cmd": "delete_item", "deviceItemId": deviceItemId}
  /// Device shifts remaining items down and updates selection if needed.
  ///
  /// Returns:
  /// - Right(void): Delete command sent successfully
  /// - Left(BluetoothFailure): Command failed
  Future<Either<Failure, void>> deleteItem(
    String deviceId,
    int deviceItemId,
  );

  /// Unpairs the device from the current account.
  ///
  /// Sends JSON: {"cmd": "unpair"}
  /// Clears pairing data (UID) on the device so it can be paired to another account.
  /// Should be called AFTER clearing items and logs.
  ///
  /// Returns:
  /// - Right(void): Unpair command sent successfully
  /// - Left(BluetoothFailure): Command failed
  Future<Either<Failure, void>> unpairDevice(String deviceId);

  // ============================================================
  // NOTIFICATIONS (Read from ESP32)
  // ============================================================

  /// Watches incoming messages from the ESP32 device.
  ///
  /// Subscribes to NOTIFY characteristic (12345678-1234-1234-1234-123456789002).
  /// Handles chunk assembly using newline delimiter.
  /// Parses JSON and emits BleMessage objects.
  ///
  /// Message types:
  /// - prefs: Item status updates with counts and selected item
  /// - event: Real-time events (increment, switch, etc.)
  /// - logs: Historical event logs (paginated)
  ///
  /// Returns stream of:
  /// - Right(BleMessage): Parsed message from device
  /// - Left(BluetoothFailure): Notification subscription failed or parse error
  Stream<Either<Failure, BleMessage>> watchMessages(String deviceId);

  /// Reads data directly from device (one-shot).
  ///
  /// Reads from READ characteristic (12345678-1234-1234-1234-123456789001).
  /// Used for immediate data retrieval rather than stream-based notifications.
  ///
  /// Returns:
  /// - Right(BleMessage): Parsed data from device
  /// - Left(BluetoothFailure): Read failed
  Future<Either<Failure, BleMessage>> readData(String deviceId);

  // ============================================================
  // MULTI-DEVICE SYNC COMMANDS
  // ============================================================

  /// Sends handshake command to device and waits for response.
  ///
  /// The handshake performs both:
  /// 1. Account lock check (is this device paired to this user?)
  /// 2. Sync sequence check (is this device in sync or conflicted?)
  ///
  /// [uid] - Firebase user ID
  /// [syncSeq] - App's current sync sequence number
  ///
  /// Returns:
  /// - Right(HandshakeResult): Response with status and device info
  /// - Left(BluetoothFailure): Command failed or timed out
  Future<Either<Failure, HandshakeResult>> sendHandshake({
    required String uid,
    required int syncSeq,
  });

  /// Sends override data to device using chunked protocol.
  ///
  /// Used when sync_seq mismatch detected (app is source of truth).
  /// Items are chunked (10 per chunk) to fit BLE MTU limits.
  ///
  /// [uid] - Firebase user ID (stored on device for account lock)
  /// [syncSeq] - New sync sequence number
  /// [selectedId] - Device item ID to select (-1 for none)
  /// [items] - Items to push to device
  /// [categoryNames] - Map of categoryId to category name
  ///
  /// Returns:
  /// - Right(OverrideResult): Override completed or error
  /// - Left(BluetoothFailure): BLE error (override aborted)
  Future<Either<Failure, OverrideResult>> sendOverrideChunked({
    required String uid,
    required int syncSeq,
    required int selectedId,
    required List<Item> items,
    Map<String, String> categoryNames = const {},
  });

  /// Sends sync_complete command to device.
  ///
  /// Called after normal sync (device -> app) to update device's sync_seq.
  /// Wait for acknowledgment before updating Firestore.
  ///
  /// [syncSeq] - New sync sequence number
  ///
  /// Returns:
  /// - Right(SyncCompleteResult): Device stored the new sync_seq
  /// - Left(BluetoothFailure): Command failed or timed out
  Future<Either<Failure, SyncCompleteResult>> sendSyncComplete(int syncSeq);

  // ============================================================
  // PERMISSIONS & ADAPTER STATE
  // ============================================================

  /// Checks if Bluetooth is enabled on the device.
  ///
  /// Returns:
  /// - Right(true): Bluetooth adapter is on
  /// - Right(false): Bluetooth adapter is off
  /// - Left(BluetoothFailure): Failed to check adapter state
  Future<Either<Failure, bool>> isBluetoothEnabled();

  /// Requests required Bluetooth permissions.
  ///
  /// On Android 12+: BLUETOOTH_SCAN, BLUETOOTH_CONNECT
  /// Also requests location permission for BLE scanning.
  ///
  /// Returns:
  /// - Right(true): All permissions granted
  /// - Right(false): Permissions denied
  /// - Left(BluetoothFailure): Permission request failed
  Future<Either<Failure, bool>> requestPermissions();
}
