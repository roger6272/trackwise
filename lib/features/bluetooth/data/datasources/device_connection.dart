import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../../core/utils/bluetooth_constants.dart';
import '../../domain/entities/ble_message.dart';

/// Encapsulates all per-device BLE state for a single connection.
///
/// Created by BluetoothDataSourceImpl.connect(), disposed on disconnect.
/// Each connected device gets its own DeviceConnection instance.
class DeviceConnection {
  final String deviceInstanceId;

  // The underlying BLE device handle
  BluetoothDevice? device;

  // Cached characteristics (discovered on connect)
  BluetoothCharacteristic? readChar;
  BluetoothCharacteristic? notifyChar;
  BluetoothCharacteristic? setItemsChar;
  BluetoothCharacteristic? writeChar;

  // Optional characteristics (may not be present on older firmware)
  BluetoothCharacteristic? otaDataChar;
  BluetoothCharacteristic? batteryLevelChar;

  // Connection
  int negotiatedMtu = BluetoothConstants.defaultMtuLimit;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  // Message assembly
  StreamSubscription<List<int>>? notifySubscription;
  final messageController = StreamController<BleMessage>.broadcast();
  final messageBuffer = StringBuffer();
  Timer? messageTimeoutTimer;

  // Battery level (optional — only present on firmware with Battery Service)
  StreamSubscription<List<int>>? batteryLevelSubscription;
  final batteryLevelController = StreamController<int>.broadcast();

  // Write serialization (per-device queue)
  final writeQueue = <WriteOperation>[];
  bool isProcessingWrite = false;

  DeviceConnection({required this.deviceInstanceId});

  /// Clears cached characteristics and resets MTU.
  void clearConnectionState() {
    readChar = null;
    notifyChar = null;
    setItemsChar = null;
    writeChar = null;
    otaDataChar = null;
    batteryLevelChar = null;
    negotiatedMtu = BluetoothConstants.defaultMtuLimit;
    notifySubscription?.cancel();
    notifySubscription = null;
    batteryLevelSubscription?.cancel();
    batteryLevelSubscription = null;
    messageBuffer.clear();
    messageTimeoutTimer?.cancel();
    messageTimeoutTimer = null;
  }

  /// Releases all resources for this connection.
  Future<void> dispose() async {
    connectionSubscription?.cancel();
    connectionSubscription = null;
    notifySubscription?.cancel();
    notifySubscription = null;
    batteryLevelSubscription?.cancel();
    batteryLevelSubscription = null;
    messageTimeoutTimer?.cancel();
    messageTimeoutTimer = null;
    messageBuffer.clear();
    writeQueue.clear();
    if (!messageController.isClosed) {
      await messageController.close();
    }
    if (!batteryLevelController.isClosed) {
      await batteryLevelController.close();
    }
  }
}

/// A queued write operation for BLE serialization.
class WriteOperation {
  final Future<void> Function() execute;
  final Completer<void> completer;

  WriteOperation({
    required this.execute,
    required this.completer,
  });
}
