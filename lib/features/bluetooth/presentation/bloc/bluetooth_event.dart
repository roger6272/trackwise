import 'package:equatable/equatable.dart';

import '../../../items/domain/entities/item.dart';
import '../../domain/entities/ble_device.dart';
import '../../domain/entities/ble_message.dart';
import '../../domain/usecases/request_device_data_usecase.dart';
import '../../domain/usecases/sync_usecase.dart';

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
  final String deviceInstanceId;

  const DisconnectFromDevice({required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}

/// Internal event when connection state changes.
class ConnectionStateChanged extends BluetoothEvent {
  final bool isConnected;
  final String deviceInstanceId;

  const ConnectionStateChanged({
    required this.isConnected,
    required this.deviceInstanceId,
  });

  @override
  List<Object?> get props => [isConnected, deviceInstanceId];
}

// ========== Data Events ==========

/// Send item list to the connected ESP32 device.
class SendItemsToDevice extends BluetoothEvent {
  final List<Item> items;
  final String deviceInstanceId;

  /// Map of categoryId -> categoryName for resolving category names.
  final Map<String, String> categoryNames;

  const SendItemsToDevice(
    this.items, {
    required this.deviceInstanceId,
    this.categoryNames = const {},
  });

  @override
  List<Object?> get props => [items, deviceInstanceId, categoryNames];
}

/// Send selected item change to the ESP32 device.
class SendSelectedItem extends BluetoothEvent {
  /// Firestore ID for app-side tracking
  final String itemId;

  /// Device-side ID (0-99) for BLE communication
  final int deviceItemId;

  final String deviceInstanceId;

  const SendSelectedItem(this.itemId, this.deviceItemId, {required this.deviceInstanceId});

  @override
  List<Object?> get props => [itemId, deviceItemId, deviceInstanceId];
}

/// Send time sync to the ESP32 device.
class SendTimeSync extends BluetoothEvent {
  /// Target device. When null, falls back to first connected device (single-device compat).
  final String? deviceInstanceId;

  const SendTimeSync({this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}

/// Request data from the ESP32 device.
class RequestDeviceData extends BluetoothEvent {
  final DeviceDataType type;
  final int page;
  /// Target device. When null, falls back to first connected device (single-device compat).
  final String? deviceInstanceId;

  const RequestDeviceData({
    required this.type,
    this.page = 0,
    this.deviceInstanceId,
  });

  @override
  List<Object?> get props => [type, page, deviceInstanceId];
}

/// Clear logs on the ESP32 device.
class ClearDeviceLogs extends BluetoothEvent {
  /// Target device. When null, falls back to first connected device (single-device compat).
  final String? deviceInstanceId;

  const ClearDeviceLogs({this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}

/// Unpair the device from the current account.
/// Clears pairing data (UID) so it can be paired to another account.
class UnpairDevice extends BluetoothEvent {
  /// Target device. When null, falls back to first connected device (single-device compat).
  final String? deviceInstanceId;

  const UnpairDevice({this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}

// ========== Message Events ==========

/// Internal event when a message is received from ESP32.
class MessageReceived extends BluetoothEvent {
  final BleMessage message;
  final String deviceInstanceId;

  const MessageReceived(this.message, {required this.deviceInstanceId});

  @override
  List<Object?> get props => [message, deviceInstanceId];
}

// ========== Scan Result Events ==========

/// Internal event when scan results are updated.
class ScanResultsUpdated extends BluetoothEvent {
  final List<BleDevice> devices;

  const ScanResultsUpdated(this.devices);

  @override
  List<Object?> get props => [devices];
}

/// Internal event to update selected item ID from device prefs during initial sync.
/// Used during initial sync when device reports its currently selected item.
class UpdateSelectedItemFromDevice extends BluetoothEvent {
  final String itemId;
  final String deviceInstanceId;

  const UpdateSelectedItemFromDevice(this.itemId, {required this.deviceInstanceId});

  @override
  List<Object?> get props => [itemId, deviceInstanceId];
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

/// Update a paired device's color index.
class UpdateDeviceColor extends BluetoothEvent {
  final String deviceInstanceId;
  final int newColor;

  const UpdateDeviceColor({
    required this.deviceInstanceId,
    required this.newColor,
  });

  @override
  List<Object?> get props => [deviceInstanceId, newColor];
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
  final String deviceInstanceId;

  const SyncConflictDetected({
    this.deviceSyncSeq,
    required this.appSyncSeq,
    required this.deviceInstanceId,
  });

  @override
  List<Object?> get props => [deviceSyncSeq, appSyncSeq, deviceInstanceId];
}

/// User confirmed override in conflict dialog.
/// Triggers PerformOverrideUseCase.
class ConfirmSyncOverride extends BluetoothEvent {
  /// The currently selected item ID from the app UI.
  /// Takes precedence over BluetoothState.selectedItemId.
  final String? currentSelectedItemId;

  final String deviceInstanceId;

  const ConfirmSyncOverride({
    this.currentSelectedItemId,
    required this.deviceInstanceId,
  });

  @override
  List<Object?> get props => [currentSelectedItemId, deviceInstanceId];
}

/// User cancelled conflict dialog.
/// Disconnects from device.
class CancelSyncConflict extends BluetoothEvent {
  final String deviceInstanceId;

  const CancelSyncConflict({required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
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
  /// The currently selected item ID from the app UI.
  /// Takes precedence over BluetoothState.selectedItemId.
  final String? currentSelectedItemId;

  final String deviceInstanceId;

  const ConfirmDeviceSetup({
    this.currentSelectedItemId,
    required this.deviceInstanceId,
  });

  @override
  List<Object?> get props => [currentSelectedItemId, deviceInstanceId];
}

/// User cancelled device setup dialog.
/// Disconnects from device (device stays empty/unpaired).
class CancelDeviceSetup extends BluetoothEvent {
  final String deviceInstanceId;

  const CancelDeviceSetup({required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}

/// Clear setup state after it's been handled.
class ClearSetupState extends BluetoothEvent {
  const ClearSetupState();
}

/// Internal event when sync completes successfully.
/// Sets the connected device instance ID and triggers paired devices reload.
class SyncCompleted extends BluetoothEvent {
  final String deviceInstanceId;

  const SyncCompleted({required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}

// ========== Wrong Account Events (device paired to different user) ==========

/// Internal event when device is locked to a different user account.
/// UI should show wrong account dialog and disconnect.
class WrongAccountDetected extends BluetoothEvent {
  const WrongAccountDetected();
}

/// User dismissed wrong account dialog.
/// Disconnects from device.
class DismissWrongAccount extends BluetoothEvent {
  const DismissWrongAccount();
}

// ========== Handshake Events ==========

/// Internal event when handshake completes (success, conflict, setup, or wrongAccount).
class HandshakeCompleted extends BluetoothEvent {
  final String deviceInstanceId;
  final SyncResult result;

  const HandshakeCompleted({required this.deviceInstanceId, required this.result});

  @override
  List<Object?> get props => [deviceInstanceId, result];
}

// ========== Claim Events ==========

/// Claim an item for exclusive use by a device.
class ClaimItem extends BluetoothEvent {
  final String itemId;
  final String deviceInstanceId;
  /// Previous item ID to release (captured before optimistic update).
  final String? previousItemId;
  /// True when this claim originates from a device prefs echo (not user action).
  /// Device-echo claims still write to Firestore but do NOT push to other
  /// devices, preventing A→B→A cascading updates.
  final bool fromDeviceEcho;

  const ClaimItem({
    required this.itemId,
    required this.deviceInstanceId,
    this.previousItemId,
    this.fromDeviceEcho = false,
  });

  @override
  List<Object?> get props => [itemId, deviceInstanceId, previousItemId, fromDeviceEcho];
}

/// Release a claim on an item.
class ReleaseItem extends BluetoothEvent {
  final String itemId;

  /// Device instance ID that currently claims this item (for stale-claim tracking).
  final String? claimedBy;

  /// Item name (for stale-claim dialog messaging).
  final String? itemName;

  const ReleaseItem({required this.itemId, this.claimedBy, this.itemName});

  @override
  List<Object?> get props => [itemId, claimedBy, itemName];
}

/// Triggers a claim-filtered item push to all connected devices.
/// Used after item reorder/edits in multi-device mode where the UI-layer
/// sync path (_checkDeviceSync) cannot apply per-device claim filtering.
class RefreshAllDevices extends BluetoothEvent {
  const RefreshAllDevices();

  @override
  List<Object?> get props => [];
}
