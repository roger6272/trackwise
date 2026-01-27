import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../items/domain/entities/item.dart';
import '../../domain/entities/ble_connection_state.dart';
import '../../domain/entities/ble_message.dart';
import '../../domain/entities/sync_state.dart';
import '../models/ble_device_model.dart';

/// Abstract interface for Bluetooth Low Energy operations.
///
/// This interface abstracts the flutter_blue_plus implementation,
/// enabling testability through mock implementations.
abstract class BluetoothDataSource {
  // ========== Scanning ==========

  /// Scans for nearby BLE devices.
  ///
  /// Returns a stream of discovered devices. Each emission contains
  /// the full list of devices found so far (not incremental updates).
  ///
  /// [timeout] - How long to scan before stopping
  /// [filterByName] - Optional device name prefix filter
  Stream<List<BleDeviceModel>> scanDevices({
    Duration timeout = const Duration(seconds: 15),
    String? filterByName,
  });

  /// Stops an active BLE scan.
  Future<void> stopScan();

  /// Whether a scan is currently in progress.
  bool get isScanning;

  // ========== Connection ==========

  /// Connects to a BLE device by its ID.
  ///
  /// Returns the BluetoothDevice if successful.
  /// Throws exception on failure.
  Future<BluetoothDevice> connect(String deviceId);

  /// Disconnects from a connected device.
  Future<void> disconnect(String deviceId);

  /// Gets the currently connected device, if any.
  BleDeviceModel? get connectedDevice;

  /// Watches the connection state of a device.
  ///
  /// Emits state changes: connecting, connected, disconnected.
  Stream<BleConnectionState> watchConnectionState(String deviceId);

  /// Emits the connected state.
  ///
  /// Should be called by the repository AFTER discoverServices() completes
  /// to ensure characteristics are cached before any listeners react.
  void emitConnectedState();

  // ========== Characteristics ==========

  /// Discovers services and characteristics on a connected device.
  ///
  /// Must be called after connection before reading/writing.
  Future<void> discoverServices(BluetoothDevice device);

  /// Writes data to the SET_ITEMS characteristic.
  ///
  /// Used for sending the item list to ESP32.
  /// Handles chunking automatically.
  Future<void> writeItems(String deviceId, String jsonData);

  /// Writes data to the WRITE characteristic.
  ///
  /// Used for sending commands (selected item, time sync, data requests).
  /// Handles chunking automatically.
  Future<void> writeCommand(String deviceId, String jsonData);

  /// Writes a raw command without newline delimiter.
  ///
  /// Used for prepare_read commands that expect immediate response.
  Future<void> writeCommandRaw(String jsonData);

  /// Reads data from the READ characteristic.
  Future<String> readData(String deviceId);

  /// Rediscovers services and reads data from READ characteristic.
  ///
  /// This mirrors the old code pattern where discoverServices() is called
  /// again before reading, which may trigger the ESP32 to update the
  /// READ characteristic with fresh data.
  Future<String> rediscoverAndReadData(String deviceId);

  /// Performs the full prepare_read cycle matching old code exactly:
  /// 1. discoverServices → get writeChar → write command
  /// 2. discoverServices → get readChar → read response
  Future<String> prepareReadCycle(String command);

  /// Emits a message to the notification stream.
  ///
  /// Used by repository to inject messages from READ characteristic
  /// into the same stream as NOTIFY messages, allowing uniform handling.
  void emitMessage(BleMessage message);

  /// Subscribes to notifications from the NOTIFY characteristic.
  ///
  /// Returns a stream of parsed BleMessage objects.
  /// Handles chunk assembly automatically.
  Stream<BleMessage> watchNotifications(String deviceId);

  // ========== Multi-Device Sync Commands ==========

  /// Sends handshake command to device and waits for response.
  ///
  /// The handshake performs both:
  /// 1. Account lock check (is this device paired to this user?)
  /// 2. Sync sequence check (is this device in sync or conflicted?)
  ///
  /// Sends: `{"cmd":"handshake","uid":"xxx","sync_seq":42}`
  ///
  /// Returns [HandshakeResult] with status:
  /// - [SyncStatus.inSync]: Device sync_seq matches, proceed with normal sync
  /// - [SyncStatus.conflict]: sync_seq mismatch, app should override device
  /// - [SyncStatus.wrongAccount]: Device paired to different account
  ///
  /// Throws on BLE error or 10-second timeout.
  Future<HandshakeResult> sendHandshake({
    required String uid,
    required int syncSeq,
  });

  /// Sends override data to device using chunked protocol.
  ///
  /// Override flow:
  /// 1. Send `{"cmd":"override_start","uid":"xxx","sync_seq":N,"total_chunks":M}`
  /// 2. Send `{"cmd":"override_chunk","index":i,"items":[...]}` for each chunk
  /// 3. Send `{"cmd":"override_end","selected_id":X}`
  /// 4. Wait for response
  ///
  /// Items are chunked (10 items per chunk) to fit BLE MTU limits.
  /// Individual chunks don't have responses - validation occurs at override_end.
  ///
  /// [uid] is the Firebase user ID - device stores this on first setup.
  /// [categoryNames] maps categoryId to category name for device display.
  ///
  /// Returns [OverrideResult] with status:
  /// - 'override_complete': Override succeeded
  /// - 'error': Override failed (e.g., missing_chunks)
  ///
  /// Throws on BLE error during any chunk send (aborts override).
  Future<OverrideResult> sendOverrideChunked({
    required String uid,
    required int syncSeq,
    required int selectedId,
    required List<Item> items,
    Map<String, String> categoryNames = const {},
  });

  /// Sends sync_complete command to device and waits for acknowledgment.
  ///
  /// Called after normal sync (device -> app) to update device's sync_seq.
  ///
  /// Sends: `{"cmd":"sync_complete","sync_seq":N}`
  ///
  /// Returns [SyncCompleteResult] with status:
  /// - 'seq_updated': Device stored the new sync_seq
  ///
  /// Throws on BLE error or 10-second timeout.
  Future<SyncCompleteResult> sendSyncComplete(int syncSeq);

  // ========== Permissions & Adapter State ==========

  /// Checks if Bluetooth adapter is enabled.
  Future<bool> isBluetoothEnabled();

  /// Watches Bluetooth adapter state changes.
  Stream<bool> watchBluetoothState();

  /// Requests Bluetooth permissions from the OS.
  ///
  /// Returns true if all permissions granted.
  Future<bool> requestPermissions();

  // ========== Cleanup ==========

  /// Releases all resources and closes streams.
  Future<void> dispose();
}
