import 'package:equatable/equatable.dart';

import '../../../items/domain/entities/item.dart';
import '../../domain/entities/ble_device.dart';
import '../../domain/entities/ble_message.dart';
import '../../domain/usecases/request_device_data_usecase.dart';

/// Base class for all Bluetooth BLoC events.
abstract class BluetoothEvent extends Equatable {
  const BluetoothEvent();

  @override
  List<Object?> get props => [];
}

// ========== Permission Events ==========

/// Check if Bluetooth permissions are granted.
class CheckBluetoothPermissions extends BluetoothEvent {
  const CheckBluetoothPermissions();
}

/// Request Bluetooth permissions from the OS.
class RequestBluetoothPermissions extends BluetoothEvent {
  const RequestBluetoothPermissions();
}

// ========== Adapter State Events ==========

/// Check if Bluetooth adapter is enabled.
class CheckBluetoothEnabled extends BluetoothEvent {
  const CheckBluetoothEnabled();
}

/// Internal event when Bluetooth adapter state changes.
class BluetoothAdapterStateChanged extends BluetoothEvent {
  final bool isEnabled;

  const BluetoothAdapterStateChanged(this.isEnabled);

  @override
  List<Object?> get props => [isEnabled];
}

// ========== Scan Events ==========

/// Start scanning for BLE devices.
class StartScan extends BluetoothEvent {
  final Duration timeout;

  const StartScan({this.timeout = const Duration(seconds: 15)});

  @override
  List<Object?> get props => [timeout];
}

/// Stop an active BLE scan.
class StopScan extends BluetoothEvent {
  const StopScan();
}

// ========== Connection Events ==========

/// Connect to a BLE device.
class ConnectToDevice extends BluetoothEvent {
  final String deviceId;

  const ConnectToDevice(this.deviceId);

  @override
  List<Object?> get props => [deviceId];
}

/// Disconnect from a connected BLE device.
class DisconnectFromDevice extends BluetoothEvent {
  const DisconnectFromDevice();
}

/// Internal event when connection state changes.
class ConnectionStateChanged extends BluetoothEvent {
  final bool isConnected;
  final String? deviceId;

  const ConnectionStateChanged({
    required this.isConnected,
    this.deviceId,
  });

  @override
  List<Object?> get props => [isConnected, deviceId];
}

// ========== Data Events ==========

/// Send item list to the connected ESP32 device.
class SendItemsToDevice extends BluetoothEvent {
  final List<Item> items;

  /// Map of categoryId -> categoryName for resolving category names.
  final Map<String, String> categoryNames;

  const SendItemsToDevice(this.items, {this.categoryNames = const {}});

  @override
  List<Object?> get props => [items, categoryNames];
}

/// Send selected item change to the ESP32 device.
class SendSelectedItem extends BluetoothEvent {
  /// Firestore ID for app-side tracking
  final String itemId;

  /// Device-side ID (0-99) for BLE communication
  final int deviceItemId;

  const SendSelectedItem(this.itemId, this.deviceItemId);

  @override
  List<Object?> get props => [itemId, deviceItemId];
}

/// Send time sync to the ESP32 device.
class SendTimeSync extends BluetoothEvent {
  const SendTimeSync();
}

/// Request data from the ESP32 device.
class RequestDeviceData extends BluetoothEvent {
  final DeviceDataType type;
  final int page;

  const RequestDeviceData({
    required this.type,
    this.page = 0,
  });

  @override
  List<Object?> get props => [type, page];
}

/// Clear logs on the ESP32 device.
class ClearDeviceLogs extends BluetoothEvent {
  const ClearDeviceLogs();
}

// ========== Message Events ==========

/// Internal event when a message is received from ESP32.
class MessageReceived extends BluetoothEvent {
  final BleMessage message;

  const MessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}

// ========== Scan Result Events ==========

/// Internal event when scan results are updated.
class ScanResultsUpdated extends BluetoothEvent {
  final List<BleDevice> devices;

  const ScanResultsUpdated(this.devices);

  @override
  List<Object?> get props => [devices];
}

/// Internal event to update selected item ID from device prefs.
/// Used during initial sync when device reports its currently selected item.
class UpdateSelectedItemFromDevice extends BluetoothEvent {
  final String itemId;

  const UpdateSelectedItemFromDevice(this.itemId);

  @override
  List<Object?> get props => [itemId];
}
