import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/entities/ble_connection_state.dart';
import '../../domain/entities/ble_message.dart';
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
