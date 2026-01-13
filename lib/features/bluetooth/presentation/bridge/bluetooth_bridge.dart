// Bridge adapter for backward compatibility with FlutterFlow custom actions.
//
// This file provides functions that match the old custom action signatures
// but internally delegate to the new clean architecture BLoC.
// Use these during migration, then gradually move widgets to use BLoC directly.

import 'dart:async';

import '../../../../backend/schema/structs/index.dart';
import '../../../../core/di/injection.dart';
import '../../../../flutter_flow/flutter_flow_util.dart';
import '../../../items/domain/entities/item.dart';
import '../../domain/entities/ble_device.dart';
import '../../domain/entities/ble_message.dart';
import '../../domain/usecases/request_device_data_usecase.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';

/// Bridge class providing backward-compatible functions for FlutterFlow.
///
/// Usage:
/// ```dart
/// final bridge = BluetoothBridge();
/// final devices = await bridge.findDevices();
/// final connected = await bridge.connectDevice(devices.first);
/// ```
class BluetoothBridge {
  BluetoothBloc? _bloc;

  /// Gets or creates the BluetoothBloc instance.
  BluetoothBloc get bloc {
    _bloc ??= sl<BluetoothBloc>();
    return _bloc!;
  }

  /// Converts BleDevice entity to BTDeviceStruct for FlutterFlow compatibility.
  BTDeviceStruct _toBTDeviceStruct(BleDevice device) {
    return BTDeviceStruct(
      id: device.id,
      name: device.name,
      rssi: device.rssi,
    );
  }

  /// Converts BTDeviceStruct to device ID string.
  String _toDeviceId(BTDeviceStruct device) => device.id;

  // ========== Scanning ==========

  /// Scans for nearby BLE devices.
  ///
  /// Matches old signature: `Future<List<BTDeviceStruct>> findDevices()`
  Future<List<BTDeviceStruct>> findDevices({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<List<BTDeviceStruct>>();
    StreamSubscription<BluetoothState>? subscription;

    // Request permissions first
    bloc.add(const RequestBluetoothPermissions());

    // Wait for permissions, then start scan
    subscription = bloc.stream.listen((state) {
      if (state.status == BluetoothStatus.ready ||
          state.status == BluetoothStatus.scanning) {
        // Start scan if not already scanning
        if (state.status == BluetoothStatus.ready) {
          bloc.add(StartScan(timeout: timeout));
        }
      } else if (state.status == BluetoothStatus.permissionsDenied) {
        subscription?.cancel();
        completer.complete([]);
      }
    });

    // Wait for scan to complete
    await Future.delayed(timeout + const Duration(milliseconds: 500));
    subscription.cancel();

    // Convert discovered devices to BTDeviceStruct
    final devices = bloc.state.discoveredDevices
        .map(_toBTDeviceStruct)
        .toList();

    return devices;
  }

  /// Stops the current scan.
  Future<void> stopScan() async {
    bloc.add(const StopScan());
    // Wait for state to update
    await bloc.stream.firstWhere(
      (state) => state.status != BluetoothStatus.scanning,
    );
  }

  // ========== Connection ==========

  /// Connects to a BLE device.
  ///
  /// Matches old signature: `Future<bool> connectDevice(BTDeviceStruct deviceInfo)`
  Future<bool> connectDevice(BTDeviceStruct deviceInfo) async {
    final deviceId = _toDeviceId(deviceInfo);
    final completer = Completer<bool>();
    StreamSubscription<BluetoothState>? subscription;

    subscription = bloc.stream.listen((state) {
      if (state.status == BluetoothStatus.connected &&
          state.connectedDevice?.id == deviceId) {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      } else if (state.status == BluetoothStatus.error) {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }
    });

    bloc.add(ConnectToDevice(deviceId));

    // Timeout after 15 seconds
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        subscription?.cancel();
        return false;
      },
    );
  }

  /// Disconnects from a BLE device.
  ///
  /// Matches old signature: `Future<void> disconnectDevice(String deviceId)`
  /// Note: deviceId is kept for API compatibility but the bloc tracks connected device internally.
  Future<void> disconnectDevice(String deviceId) async {
    FFAppState().isManualDisconnect = true;
    bloc.add(const DisconnectFromDevice());

    // Wait for disconnection
    await bloc.stream.firstWhere(
      (state) => state.status != BluetoothStatus.connected,
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => bloc.state,
    );
  }

  /// Performs post-connection setup actions.
  ///
  /// Matches old signature: `Future<void> onConnectActions(BTDeviceStruct deviceInfo)`
  Future<void> onConnectActions(BTDeviceStruct deviceInfo) async {
    // Update app state
    FFAppState().deviceConnected = true;
    FFAppState().isManualDisconnect = false;

    // Connect (if not already connected)
    if (bloc.state.status != BluetoothStatus.connected) {
      await connectDevice(deviceInfo);
    }

    // Wait for connection to be fully established
    await Future.delayed(const Duration(milliseconds: 500));

    // Sync time
    bloc.add(const SendTimeSync());

    // Request device preferences
    bloc.add(const RequestDeviceData(
      type: DeviceDataType.prefs,
    ));

    // Request event logs
    bloc.add(RequestDeviceData(
      type: DeviceDataType.logs,
      page: FFAppState().currentLogPage,
    ));
  }

  // ========== Data Transfer ==========

  /// Sends items to the connected device.
  ///
  /// This is a simplified version that takes items directly.
  /// For the old behavior that fetches from Firestore, use the existing
  /// sendItemListToDevice custom action or fetch items first.
  /// Note: deviceId is kept for API compatibility but the bloc tracks connected device internally.
  Future<void> sendItems(String deviceId, List<Item> items) async {
    bloc.add(SendItemsToDevice(items));

    // Wait for completion
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Sends selected item to device.
  /// Note: deviceId is kept for API compatibility but the bloc tracks connected device internally.
  Future<void> sendSelectedItem(String deviceId, String itemId) async {
    bloc.add(SendSelectedItem(itemId));
  }

  /// Sends time sync to device.
  /// Note: deviceId is kept for API compatibility but the bloc tracks connected device internally.
  Future<void> sendTimeSync(String deviceId) async {
    bloc.add(const SendTimeSync());
  }

  /// Requests data from device (prefs or logs).
  /// Note: deviceId is kept for API compatibility but the bloc tracks connected device internally.
  Future<void> requestData(
    String deviceId,
    String type, {
    int page = 0,
  }) async {
    final requestType = type == 'prefs'
        ? DeviceDataType.prefs
        : DeviceDataType.logs;

    bloc.add(RequestDeviceData(
      type: requestType,
      page: page,
    ));
  }

  /// Clears logs on the device.
  /// Note: deviceId is kept for API compatibility but the bloc tracks connected device internally.
  Future<void> clearLogs(String deviceId) async {
    bloc.add(const ClearDeviceLogs());
  }

  // ========== State Access ==========

  /// Gets the current connection status.
  bool get isConnected => bloc.state.isConnected;

  /// Gets the connected device as BTDeviceStruct (for FlutterFlow compatibility).
  BTDeviceStruct? get connectedDevice {
    final device = bloc.state.connectedDevice;
    return device != null ? _toBTDeviceStruct(device) : null;
  }

  /// Gets discovered devices as BTDeviceStruct list.
  List<BTDeviceStruct> get discoveredDevices {
    return bloc.state.discoveredDevices
        .map(_toBTDeviceStruct)
        .toList();
  }

  /// Gets the last received message.
  BleMessage? get lastMessage => bloc.state.lastMessage;

  /// Gets the currently selected item ID from device prefs.
  String? get selectedItemId => bloc.state.selectedItemId;

  /// Whether there are more log pages to fetch.
  bool get hasMoreLogs => bloc.state.hasMoreLogs;

  /// Stream of state changes for reactive UI.
  Stream<BluetoothState> get stateStream => bloc.stream;

  // ========== Cleanup ==========

  /// Disposes resources. Call when the bridge is no longer needed.
  void dispose() {
    // Don't close the bloc here as it's managed by GetIt
    _bloc = null;
  }
}

/// Global bridge instance for easy access from FlutterFlow custom actions.
///
/// Usage in custom actions:
/// ```dart
/// final devices = await bluetoothBridge.findDevices();
/// ```
BluetoothBridge get bluetoothBridge => _bluetoothBridge ??= BluetoothBridge();
BluetoothBridge? _bluetoothBridge;

/// Resets the global bridge instance. Useful for testing.
void resetBluetoothBridge() {
  _bluetoothBridge?.dispose();
  _bluetoothBridge = null;
}
