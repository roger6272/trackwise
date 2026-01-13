import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/entities/ble_connection_state.dart';
import '../../domain/entities/ble_message.dart';
import '../models/ble_device_model.dart';
import '../models/ble_message_model.dart';
import 'bluetooth_datasource.dart';

/// Mock implementation of BluetoothDataSource for testing.
///
/// Simulates BLE operations without real hardware. Useful for:
/// - Unit testing BLoC and repository logic
/// - UI development without ESP32 device
/// - Demo/preview modes
///
/// Configure behavior using the test helper methods.
class MockBluetoothDataSource implements BluetoothDataSource {
  // ========== Configuration ==========

  /// Devices to return during scan
  List<BleDeviceModel> mockDevices = [
    const BleDeviceModel(
      id: 'MOCK-ESP32-001',
      name: 'Trackwise Device',
      rssi: -65,
      isConnectable: true,
    ),
    const BleDeviceModel(
      id: 'MOCK-ESP32-002',
      name: 'Trackwise Device 2',
      rssi: -78,
      isConnectable: true,
    ),
  ];

  /// Simulated connection delay
  Duration connectionDelay = const Duration(milliseconds: 500);

  /// Simulated scan delay before emitting results
  Duration scanDelay = const Duration(milliseconds: 200);

  /// Whether connections should fail
  bool shouldFailConnection = false;

  /// Whether scans should fail
  bool shouldFailScan = false;

  /// Whether Bluetooth is enabled
  bool bluetoothEnabled = true;

  /// Whether permissions are granted
  bool permissionsGranted = true;

  // ========== Internal State ==========

  bool _isScanning = false;
  BleDeviceModel? _connectedDevice;
  final _messageController = StreamController<BleMessage>.broadcast();
  final _connectionStateController = StreamController<BleConnectionState>.broadcast();

  @override
  bool get isScanning => _isScanning;

  @override
  BleDeviceModel? get connectedDevice => _connectedDevice;

  // ========== Scanning ==========

  @override
  Stream<List<BleDeviceModel>> scanDevices({
    Duration timeout = const Duration(seconds: 15),
    String? filterByName,
  }) async* {
    if (shouldFailScan) {
      throw Exception('Mock scan failure');
    }

    _isScanning = true;

    // Simulate scan delay
    await Future.delayed(scanDelay);

    // Filter devices if name filter provided
    var devices = mockDevices;
    if (filterByName != null) {
      devices = devices
          .where((d) => d.name.toLowerCase().contains(filterByName.toLowerCase()))
          .toList();
    }

    // Emit devices progressively
    for (var i = 1; i <= devices.length; i++) {
      if (!_isScanning) break;
      yield devices.sublist(0, i);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Wait for timeout or stop
    await Future.delayed(timeout);
    _isScanning = false;
  }

  @override
  Future<void> stopScan() async {
    _isScanning = false;
  }

  // ========== Connection ==========

  @override
  Future<BluetoothDevice> connect(String deviceId) async {
    if (shouldFailConnection) {
      throw Exception('Mock connection failure');
    }

    _connectionStateController.add(BleConnectionState.connecting);

    // Simulate connection delay
    await Future.delayed(connectionDelay);

    // Find the device in mock list or create one
    _connectedDevice = mockDevices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => BleDeviceModel.fromId(deviceId),
    );

    // NOTE: Do NOT emit connected state here!
    // The repository will call emitConnectedState() after discoverServices()

    // Return a mock BluetoothDevice
    return BluetoothDevice.fromId(deviceId);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    _connectionStateController.add(BleConnectionState.disconnecting);
    await Future.delayed(const Duration(milliseconds: 100));
    _connectedDevice = null;
    _connectionStateController.add(BleConnectionState.disconnected);
  }

  @override
  Stream<BleConnectionState> watchConnectionState(String deviceId) {
    return _connectionStateController.stream;
  }

  @override
  void emitConnectedState() {
    _connectionStateController.add(BleConnectionState.connected);
  }

  // ========== Characteristics ==========

  @override
  Future<void> discoverServices(BluetoothDevice device) async {
    // No-op for mock - services are "always discovered"
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> writeItems(String deviceId, String jsonData) async {
    // Simulate write delay
    await Future.delayed(const Duration(milliseconds: 50));
    // In real implementation, this sends items to ESP32
  }

  @override
  Future<void> writeCommand(String deviceId, String jsonData) async {
    // Simulate write delay
    await Future.delayed(const Duration(milliseconds: 50));
    // In real implementation, this sends commands to ESP32
  }

  @override
  Future<void> writeCommandRaw(String jsonData) async {
    // Simulate write delay
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<String> readData(String deviceId) async {
    // Return mock prefs data
    return '{"type":"prefs","data":[],"selected_id":null}';
  }

  @override
  Future<String> rediscoverAndReadData(String deviceId) async {
    // Simulate service discovery delay
    await Future.delayed(const Duration(milliseconds: 100));
    // Return mock prefs data
    return '{"type":"prefs","data":[],"selected_id":null}';
  }

  @override
  Future<String> prepareReadCycle(String command) async {
    // Simulate full cycle delay
    await Future.delayed(const Duration(milliseconds: 200));
    // Return mock prefs data
    return '{"type":"prefs","data":[],"selected_id":null}';
  }

  @override
  Stream<BleMessage> watchNotifications(String deviceId) {
    return _messageController.stream;
  }

  // ========== Permissions & Adapter State ==========

  @override
  Future<bool> isBluetoothEnabled() async {
    return bluetoothEnabled;
  }

  @override
  Stream<bool> watchBluetoothState() {
    return Stream.value(bluetoothEnabled);
  }

  @override
  Future<bool> requestPermissions() async {
    return permissionsGranted;
  }

  // ========== Cleanup ==========

  @override
  Future<void> dispose() async {
    await _messageController.close();
    await _connectionStateController.close();
    _connectedDevice = null;
    _isScanning = false;
  }

  // ========== Test Helpers ==========

  /// Emits a mock message as if received from ESP32.
  ///
  /// Use this to simulate device events during testing.
  void emitMessage(BleMessage message) {
    _messageController.add(message);
  }

  /// Emits a mock prefs message with given data.
  void emitPrefs(List<Map<String, dynamic>> items, {String? selectedId}) {
    final message = BleMessageModel(
      type: BleMessageType.prefs,
      data: items,
      selectedId: selectedId,
      hasMore: false,
      receivedAt: DateTime.now(),
    );
    _messageController.add(message);
  }

  /// Emits a mock event message (button press).
  void emitEvent({
    required String itemId,
    required String itemName,
    required int count,
    required int increment,
  }) {
    final message = BleMessageModel(
      type: BleMessageType.event,
      data: {
        'event': 'increment',
        'itemId': itemId,
        'itemName': itemName,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'count': count,
        'increment': increment,
      },
      hasMore: false,
      receivedAt: DateTime.now(),
    );
    _messageController.add(message);
  }

  /// Emits a mock logs message.
  void emitLogs(List<Map<String, dynamic>> logs, {bool hasMore = false}) {
    final message = BleMessageModel(
      type: BleMessageType.logs,
      data: logs,
      hasMore: hasMore,
      receivedAt: DateTime.now(),
    );
    _messageController.add(message);
  }

  /// Simulates an unexpected disconnect.
  void simulateDisconnect() {
    _connectedDevice = null;
    _connectionStateController.add(BleConnectionState.disconnected);
  }

  /// Resets all mock state to defaults.
  void reset() {
    _isScanning = false;
    _connectedDevice = null;
    shouldFailConnection = false;
    shouldFailScan = false;
    bluetoothEnabled = true;
    permissionsGranted = true;
    connectionDelay = const Duration(milliseconds: 500);
    scanDelay = const Duration(milliseconds: 200);
  }
}
