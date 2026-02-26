import 'package:equatable/equatable.dart';

import '../../domain/entities/ble_device.dart';
import '../../domain/entities/paired_device.dart';
import 'device_connection_state.dart';

/// Status of the Bluetooth BLoC.
enum BluetoothStatus {
  /// Initial state, not yet initialized
  initial,

  /// Checking permissions
  checkingPermissions,

  /// Permissions denied
  permissionsDenied,

  /// Bluetooth adapter is disabled
  bluetoothDisabled,

  /// Ready to scan/connect
  ready,

  /// Actively scanning for devices
  scanning,

  /// Connecting to a device
  connecting,

  /// An error occurred
  error,
}

/// State for the Bluetooth BLoC.
class BluetoothState extends Equatable {
  /// Current status of the BLoC
  final BluetoothStatus status;

  /// Devices discovered during scan
  final List<BleDevice> discoveredDevices;

  /// Device ID we're trying to connect to
  final String? connectingDeviceId;

  /// Error message (only set when status is error)
  final String? errorMessage;

  /// Whether Bluetooth permissions are granted
  final bool permissionsGranted;

  /// Whether Bluetooth adapter is enabled
  final bool bluetoothEnabled;

  // ========== Multi-Device Fields ==========

  /// List of devices paired to the user's account.
  final List<PairedDevice> pairedDevices;

  /// Map of deviceInstanceId -> DeviceConnectionState for all connected devices.
  /// Has 0 or 1 entries in current single-device mode.
  final Map<String, DeviceConnectionState> connectedDevices;

  const BluetoothState({
    this.status = BluetoothStatus.initial,
    this.discoveredDevices = const [],
    this.connectingDeviceId,
    this.errorMessage,
    this.permissionsGranted = false,
    this.bluetoothEnabled = false,
    this.pairedDevices = const [],
    this.connectedDevices = const {},
  });

  /// Creates a copy of this state with the given fields replaced.
  BluetoothState copyWith({
    BluetoothStatus? status,
    List<BleDevice>? discoveredDevices,
    String? connectingDeviceId,
    String? errorMessage,
    bool? permissionsGranted,
    bool? bluetoothEnabled,
    List<PairedDevice>? pairedDevices,
    Map<String, DeviceConnectionState>? connectedDevices,
    bool clearConnectingDeviceId = false,
    bool clearErrorMessage = false,
  }) {
    return BluetoothState(
      status: status ?? this.status,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectingDeviceId: clearConnectingDeviceId ? null : (connectingDeviceId ?? this.connectingDeviceId),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
      pairedDevices: pairedDevices ?? this.pairedDevices,
      connectedDevices: connectedDevices ?? this.connectedDevices,
    );
  }

  // ========== Computed Properties ==========

  /// Whether any device is connected.
  bool get isConnected => connectedDevices.isNotEmpty;

  /// Whether currently scanning.
  bool get isScanning => status == BluetoothStatus.scanning;

  /// Whether currently connecting to a device.
  bool get isConnecting => status == BluetoothStatus.connecting;

  /// Whether ready to scan/connect (permissions granted, BT enabled).
  bool get isReady =>
      status == BluetoothStatus.ready ||
      status == BluetoothStatus.scanning ||
      status == BluetoothStatus.connecting ||
      connectedDevices.isNotEmpty;

  /// Whether multiple devices are connected.
  bool get hasMultipleDevices => connectedDevices.length >= 2;

  /// Get state for a specific device by instanceId.
  DeviceConnectionState? getDevice(String id) => connectedDevices[id];

  // ========== Backward-Compatible Single-Device Getters ==========

  /// Currently connected device (null if not connected).
  BleDevice? get connectedDevice =>
      connectedDevices.isNotEmpty ? connectedDevices.values.first.device : null;

  /// Device instance ID of the currently connected device.
  String? get connectedDeviceInstanceId =>
      connectedDevices.isNotEmpty ? connectedDevices.keys.first : null;

  /// Selected item ID from the connected device.
  String? get selectedItemId =>
      connectedDevices.isNotEmpty ? connectedDevices.values.first.selectedItemId : null;

  /// Whether a sync conflict was detected.
  bool get hasConflict =>
      connectedDevices.values.any((d) => d.syncStatus == DeviceSyncStatus.conflict);

  /// Whether device needs setup (uninitialized/factory reset).
  bool get needsSetup =>
      connectedDevices.values.any((d) => d.syncStatus == DeviceSyncStatus.setup);

  /// Whether the device is locked to a different user account.
  bool get hasWrongAccount =>
      connectedDevices.values.any((d) => d.syncStatus == DeviceSyncStatus.wrongAccount);

  /// Whether initial sync is in progress after connecting.
  bool get isSyncing => connectedDevices.values.any(
        (d) =>
            d.syncStatus == DeviceSyncStatus.handshaking ||
            d.syncStatus == DeviceSyncStatus.syncing,
      );

  /// Whether an override sync is in progress.
  bool get isOverriding => connectedDevices.values.any((d) => d.isOverriding);

  /// Whether more log pages are available.
  bool get hasMoreLogs => connectedDevices.values.any((d) => d.hasMoreLogs);

  /// App's sync sequence number (from first conflicting device).
  int? get conflictAppSyncSeq {
    for (final d in connectedDevices.values) {
      if (d.syncStatus == DeviceSyncStatus.conflict) return d.conflictAppSyncSeq;
    }
    return null;
  }

  /// Device's sync sequence number (from first conflicting device).
  int? get conflictDeviceSyncSeq {
    for (final d in connectedDevices.values) {
      if (d.syncStatus == DeviceSyncStatus.conflict) return d.conflictDeviceSyncSeq;
    }
    return null;
  }

  /// Device instance ID of the device in conflict state.
  String? get conflictDeviceInstanceId {
    for (final entry in connectedDevices.entries) {
      if (entry.value.syncStatus == DeviceSyncStatus.conflict) return entry.key;
    }
    return null;
  }

  /// Device instance ID of the device needing setup.
  String? get setupDeviceInstanceId {
    for (final entry in connectedDevices.entries) {
      if (entry.value.syncStatus == DeviceSyncStatus.setup) return entry.key;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        status,
        discoveredDevices,
        connectingDeviceId,
        errorMessage,
        permissionsGranted,
        bluetoothEnabled,
        pairedDevices,
        connectedDevices,
      ];

  @override
  String toString() {
    return 'BluetoothState(status: $status, devices: ${discoveredDevices.length}, '
        'connected: ${connectedDevice?.name ?? 'none'}, error: $errorMessage)';
  }
}
