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

  // Connection
  int negotiatedMtu = BluetoothConstants.defaultMtuLimit;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  // Message assembly
  StreamSubscription<List<int>>? notifySubscription;
  final messageController = StreamController<BleMessage>.broadcast();
  final messageBuffer = StringBuffer();
  Timer? messageTimeoutTimer;

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
    negotiatedMtu = BluetoothConstants.defaultMtuLimit;
    notifySubscription?.cancel();
    notifySubscription = null;
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
    messageTimeoutTimer?.cancel();
    messageTimeoutTimer = null;
    messageBuffer.clear();
    writeQueue.clear();
    if (!messageController.isClosed) {
      await messageController.close();
    }
  }
}

/// A queued write operation for BLE serialization.
class WriteOperation {
  final BluetoothCharacteristic characteristic;
  final String data;
  final Completer<void> completer;

  WriteOperation({
    required this.characteristic,
    required this.data,
    required this.completer,
  });
}
