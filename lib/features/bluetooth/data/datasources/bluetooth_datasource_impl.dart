import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/utils/bluetooth_constants.dart';
import '../../domain/entities/ble_connection_state.dart';
import '../../domain/entities/ble_message.dart';
import '../models/ble_device_model.dart';
import '../models/ble_message_model.dart';
import 'bluetooth_datasource.dart';

/// Real implementation of BluetoothDataSource using flutter_blue_plus.
///
/// Handles all BLE operations including:
/// - Device scanning with filtering
/// - Connection management
/// - Chunked writes (180-byte MTU, 30ms delay)
/// - Chunk assembly for incoming messages
/// - Notification subscriptions
@LazySingleton(as: BluetoothDataSource)
class BluetoothDataSourceImpl implements BluetoothDataSource {
  BluetoothDevice? _connectedDevice;
  BleDeviceModel? _connectedDeviceModel;

  // Cached characteristics
  BluetoothCharacteristic? _readChar;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _setItemsChar;
  BluetoothCharacteristic? _writeChar;

  // Notification stream management
  StreamSubscription<List<int>>? _notifySubscription;
  final _messageController = StreamController<BleMessage>.broadcast();
  final _messageBuffer = StringBuffer();

  // Connection state tracking
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  final _connectionStateController = StreamController<BleConnectionState>.broadcast();

  @override
  bool get isScanning => FlutterBluePlus.isScanningNow;

  @override
  BleDeviceModel? get connectedDevice => _connectedDeviceModel;

  // ========== Scanning ==========

  @override
  Stream<List<BleDeviceModel>> scanDevices({
    Duration timeout = const Duration(seconds: 15),
    String? filterByName,
  }) {
    final controller = StreamController<List<BleDeviceModel>>();
    final devices = <String, BleDeviceModel>{};

    StreamSubscription<List<ScanResult>>? scanSubscription;

    controller.onListen = () async {
      // IMPORTANT: Set up listener BEFORE starting scan to avoid race condition
      scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (final result in results) {
            // Only include devices with a name
            if (result.device.platformName.isEmpty) {
              continue;
            }

            // Apply name filter if provided
            if (filterByName != null) {
              if (!result.device.platformName.toLowerCase()
                  .contains(filterByName.toLowerCase())) {
                continue;
              }
            }

            final model = BleDeviceModel.fromScanResult(result);
            devices[model.id] = model;
          }

          // Emit sorted by RSSI (strongest first)
          final sortedDevices = devices.values.toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
          controller.add(sortedDevices);
        },
        onError: controller.addError,
      );

      // Wait for Bluetooth adapter to be on
      await FlutterBluePlus.adapterState
          .where((val) => val == BluetoothAdapterState.on)
          .first;

      // Now start the scan
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      // When scan completes
      FlutterBluePlus.isScanning.where((s) => !s).first.then((_) {
        if (!controller.isClosed) {
          controller.close();
        }
      });
    };

    controller.onCancel = () {
      scanSubscription?.cancel();
      FlutterBluePlus.stopScan();
    };

    return controller.stream;
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // ========== Connection ==========

  @override
  Future<BluetoothDevice> connect(String deviceId) async {
    // Disconnect from any existing connection
    if (_connectedDevice != null) {
      await disconnect(_connectedDevice!.remoteId.str);
    }

    final device = BluetoothDevice.fromId(deviceId);

    await device.connect(
      license: License.free,
      timeout: const Duration(seconds: BluetoothConstants.connectionTimeoutSeconds),
      autoConnect: false,
    );

    _connectedDevice = device;
    _connectedDeviceModel = BleDeviceModel.fromBluetoothDevice(device);

    // Set up connection state monitoring
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      // Only emit disconnected state here - connected state will be emitted
      // after service discovery completes to avoid race conditions
      if (state == BluetoothConnectionState.disconnected) {
        _connectionStateController.add(BleConnectionState.disconnected);
        _clearConnectionState();
      }
    });

    // NOTE: Do NOT emit connected state here!
    // The repository will call emitConnectedState() after discoverServices() completes
    // to ensure characteristics are cached before any code reacts to "connected"

    return device;
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    await device.disconnect();
    _clearConnectionState();
  }

  void _clearConnectionState() {
    _connectedDevice = null;
    _connectedDeviceModel = null;
    _readChar = null;
    _notifyChar = null;
    _setItemsChar = null;
    _writeChar = null;
    _notifySubscription?.cancel();
    _notifySubscription = null;
    _messageBuffer.clear();
  }

  BleConnectionState _mapConnectionState(BluetoothConnectionState state) {
    switch (state) {
      case BluetoothConnectionState.connected:
        return BleConnectionState.connected;
      case BluetoothConnectionState.disconnected:
        return BleConnectionState.disconnected;
      default:
        return BleConnectionState.connecting;
    }
  }

  @override
  Stream<BleConnectionState> watchConnectionState(String deviceId) {
    // Use our internal controller which gets updated when we connect
    // This ensures we don't miss any state changes
    return _connectionStateController.stream;
  }

  @override
  void emitConnectedState() {
    _connectionStateController.add(BleConnectionState.connected);
  }

  // ========== Services & Characteristics ==========

  @override
  Future<void> discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();

    // Search ALL services for our characteristics (like the old working code)
    // Don't filter by service UUID - just find characteristics by their UUIDs
    for (final service in services) {
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();

        if (uuid == BluetoothConstants.readCharacteristicUUID.toLowerCase()) {
          _readChar = char;
        } else if (uuid == BluetoothConstants.notifyCharacteristicUUID.toLowerCase()) {
          _notifyChar = char;
        } else if (uuid == BluetoothConstants.setItemsCharacteristicUUID.toLowerCase()) {
          _setItemsChar = char;
        } else if (uuid == BluetoothConstants.writeCharacteristicUUID.toLowerCase()) {
          _writeChar = char;
        }
      }
    }

    // Subscribe to notifications if characteristic found
    if (_notifyChar != null) {
      await _subscribeToNotifications();
    }
  }

  Future<void> _subscribeToNotifications() async {
    if (_notifyChar == null) return;

    await _notifyChar!.setNotifyValue(true);

    _notifySubscription?.cancel();
    _notifySubscription = _notifyChar!.lastValueStream.listen(
      _handleNotificationData,
      onError: (error) {
        _messageController.addError(error);
      },
    );
  }

  void _handleNotificationData(List<int> data) {
    if (data.isEmpty) return;

    // Decode bytes to string and add to buffer
    final chunk = utf8.decode(data, allowMalformed: true);
    _messageBuffer.write(chunk);

    // Check for complete messages (newline delimiter)
    _processMessageBuffer();
  }

  void _processMessageBuffer() {
    var content = _messageBuffer.toString();

    while (content.contains('\n')) {
      final idx = content.indexOf('\n');
      final messageJson = content.substring(0, idx);

      // Update content for next iteration
      content = content.substring(idx + 1);

      if (messageJson.trim().isEmpty) continue;

      try {
        final message = BleMessageModel.fromJson(messageJson);
        _messageController.add(message);
      } catch (e) {
        // Parsing error - message may be malformed, skip it
      }
    }

    // Store remaining content back in buffer
    _messageBuffer.clear();
    _messageBuffer.write(content);
  }

  // ========== Write Operations ==========

  @override
  Future<void> writeItems(String deviceId, String jsonData) async {
    if (_setItemsChar == null) {
      throw StateError('SET_ITEMS characteristic not found. Call discoverServices first.');
    }
    await _writeChunked(_setItemsChar!, jsonData);
  }

  @override
  Future<void> writeCommand(String deviceId, String jsonData) async {
    if (_writeChar == null) {
      throw StateError('WRITE characteristic not found. Call discoverServices first.');
    }
    await _writeChunked(_writeChar!, jsonData);
  }

  /// Writes a command without newline delimiter (for prepare_read commands).
  Future<void> writeCommandRaw(String jsonData) async {
    if (_writeChar == null) {
      throw StateError('WRITE characteristic not found. Call discoverServices first.');
    }
    // Write directly without adding newline (matches old prepareBLERead behavior)
    final bytes = utf8.encode(jsonData);
    await _writeChar!.write(bytes, withoutResponse: false);
  }

  /// Writes data in chunks to respect MTU limits.
  ///
  /// ESP32 requires:
  /// - Max 180 bytes per chunk
  /// - 30ms delay between chunks
  Future<void> _writeChunked(
    BluetoothCharacteristic char,
    String data,
  ) async {
    // Send raw data without delimiter (matches old FlutterFlow behavior)
    final bytes = utf8.encode(data);

    const mtu = BluetoothConstants.mtuLimit;
    const chunkDelay = Duration(milliseconds: BluetoothConstants.chunkDelayMs);

    for (var i = 0; i < bytes.length; i += mtu) {
      final end = (i + mtu < bytes.length) ? i + mtu : bytes.length;
      final chunk = bytes.sublist(i, end);

      await char.write(chunk, withoutResponse: false);

      // Delay between chunks (except after last chunk)
      if (end < bytes.length) {
        await Future.delayed(chunkDelay);
      }
    }
  }

  // ========== Read Operations ==========

  @override
  Future<String> readData(String deviceId) async {
    if (_readChar == null) {
      throw StateError('READ characteristic not found. Call discoverServices first.');
    }

    final bytes = await _readChar!.read();
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Future<String> rediscoverAndReadData(String deviceId) async {
    if (_connectedDevice == null) {
      throw StateError('Not connected to any device.');
    }

    // Rediscover services - this is the key pattern from old working code
    // The old readBLEDataAndHandle calls discoverServices() again before reading
    final services = await _connectedDevice!.discoverServices();

    // Find READ characteristic again (matches old code pattern exactly)
    BluetoothCharacteristic? readChar;
    for (final service in services) {
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == BluetoothConstants.readCharacteristicUUID.toLowerCase()) {
          readChar = char;
          break;
        }
      }
      if (readChar != null) break;
    }

    if (readChar == null) {
      throw StateError('READ characteristic not found after rediscovery.');
    }

    // Read from the freshly discovered characteristic
    final bytes = await readChar.read();
    final result = utf8.decode(bytes, allowMalformed: true);
    return result;
  }

  @override
  Future<String> prepareReadCycle(String command) async {
    if (_connectedDevice == null) {
      throw StateError('Not connected to any device.');
    }

    final deviceId = _connectedDevice!.remoteId.str;

    // MATCH OLD CODE EXACTLY: Create new BluetoothDevice object each time
    // Old prepareBLERead: final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    final writeDevice = BluetoothDevice.fromId(deviceId);

    // STEP 1: Discover services and write command (matches prepareBLERead exactly)
    var services = await writeDevice.discoverServices();

    BluetoothCharacteristic? writeChar;
    for (final service in services) {
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == BluetoothConstants.writeCharacteristicUUID.toLowerCase()) {
          writeChar = char;
          break;
        }
      }
      if (writeChar != null) break;
    }

    if (writeChar == null) {
      throw StateError('WRITE characteristic not found.');
    }

    await writeChar.write(utf8.encode(command), withoutResponse: false);

    // Add delay to give ESP32 time to process command and update READ characteristic
    await Future.delayed(const Duration(milliseconds: 500));

    // MATCH OLD CODE EXACTLY: Create ANOTHER new BluetoothDevice object for read
    // Old readBLEDataAndHandle: final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    final readDevice = BluetoothDevice.fromId(deviceId);

    // STEP 2: Discover services AGAIN and read (matches readBLEDataAndHandle exactly)
    services = await readDevice.discoverServices();

    BluetoothCharacteristic? readChar;
    for (final service in services) {
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == BluetoothConstants.readCharacteristicUUID.toLowerCase()) {
          readChar = char;
          break;
        }
      }
      if (readChar != null) break;
    }

    if (readChar == null) {
      throw StateError('READ characteristic not found.');
    }

    final bytes = await readChar.read();
    final result = utf8.decode(bytes, allowMalformed: true);
    return result;
  }

  @override
  Stream<BleMessage> watchNotifications(String deviceId) {
    return _messageController.stream;
  }

  // ========== Permissions & Adapter State ==========

  @override
  Future<bool> isBluetoothEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  @override
  Stream<bool> watchBluetoothState() {
    return FlutterBluePlus.adapterState.map(
      (state) => state == BluetoothAdapterState.on,
    );
  }

  @override
  Future<bool> requestPermissions() async {
    // Request Bluetooth permissions (Android 12+)
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();

    // Request location permission (required for BLE scanning)
    final location = await Permission.locationWhenInUse.request();

    return bluetoothScan.isGranted &&
           bluetoothConnect.isGranted &&
           location.isGranted;
  }

  // ========== Cleanup ==========

  @override
  Future<void> dispose() async {
    await _notifySubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _messageController.close();
    await _connectionStateController.close();

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }

    _clearConnectionState();
  }
}
