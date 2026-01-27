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

// ========== Paired Device Events ==========

/// Load paired devices from user's Firestore document.
class LoadPairedDevices extends BluetoothEvent {
  const LoadPairedDevices();
}

/// Internal event when paired devices list is updated.
class PairedDevicesUpdated extends BluetoothEvent {
  final List<BleDevice> devices;

  const PairedDevicesUpdated(this.devices);

  @override
  List<Object?> get props => [devices];
}

/// Rename a paired device.
class UpdateDeviceName extends BluetoothEvent {
  final String deviceInstanceId;
  final String newName;

  const UpdateDeviceName({
    required this.deviceInstanceId,
    required this.newName,
  });

  @override
  List<Object?> get props => [deviceInstanceId, newName];
}

/// Remove a paired device from the user's list.
class RemovePairedDevice extends BluetoothEvent {
  final String deviceInstanceId;

  const RemovePairedDevice(this.deviceInstanceId);

  @override
  List<Object?> get props => [deviceInstanceId];
}

// ========== Sync Conflict Events ==========

/// Internal event when a sync conflict is detected.
/// UI should show the conflict dialog.
class SyncConflictDetected extends BluetoothEvent {
  final int? deviceSyncSeq;
  final int appSyncSeq;
  final String? deviceInstanceId;

  const SyncConflictDetected({
    this.deviceSyncSeq,
    required this.appSyncSeq,
    this.deviceInstanceId,
  });

  @override
  List<Object?> get props => [deviceSyncSeq, appSyncSeq, deviceInstanceId];
}

/// User confirmed override in conflict dialog.
/// Triggers PerformOverrideUseCase.
class ConfirmSyncOverride extends BluetoothEvent {
  const ConfirmSyncOverride();
}

/// User cancelled conflict dialog.
/// Disconnects from device.
class CancelSyncConflict extends BluetoothEvent {
  const CancelSyncConflict();
}

/// Clear conflict state after it's been handled.
class ClearConflictState extends BluetoothEvent {
  const ClearConflictState();
}

// ========== Device Setup Events (for uninitialized/factory reset devices) ==========

/// Internal event when an uninitialized device is detected.
/// UI should show setup dialog: "New device detected. Transfer your items?"
class DeviceSetupRequired extends BluetoothEvent {
  final String deviceInstanceId;

  const DeviceSetupRequired({required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}

/// User confirmed device setup in dialog.
/// Triggers override to transfer items to device.
class ConfirmDeviceSetup extends BluetoothEvent {
  const ConfirmDeviceSetup();
}

/// User cancelled device setup dialog.
/// Disconnects from device (device stays empty/unpaired).
class CancelDeviceSetup extends BluetoothEvent {
  const CancelDeviceSetup();
}

/// Clear setup state after it's been handled.
class ClearSetupState extends BluetoothEvent {
  const ClearSetupState();
}

/// Internal event when sync completes successfully.
/// Sets the connected device instance ID and triggers paired devices reload.
class SyncCompleted extends BluetoothEvent {
  final String? deviceInstanceId;

  const SyncCompleted({this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}
