import 'package:equatable/equatable.dart';

import '../../domain/entities/ble_device.dart';
import '../../domain/entities/ble_message.dart';

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

  /// Connected to a device
  connected,

  /// Disconnecting from a device
  disconnecting,

  /// An error occurred
  error,
}

/// State for the Bluetooth BLoC.
class BluetoothState extends Equatable {
  /// Current status of the BLoC
  final BluetoothStatus status;

  /// Devices discovered during scan
  final List<BleDevice> discoveredDevices;

  /// Currently connected device (null if not connected)
  final BleDevice? connectedDevice;

  /// Device ID we're trying to connect to
  final String? connectingDeviceId;

  /// Error message (only set when status is error)
  final String? errorMessage;

  /// Latest message received from ESP32
  final BleMessage? lastMessage;

  /// Selected item ID from ESP32 prefs
  final String? selectedItemId;

  /// Whether more log pages are available
  final bool hasMoreLogs;

  /// Whether Bluetooth permissions are granted
  final bool permissionsGranted;

  /// Whether Bluetooth adapter is enabled
  final bool bluetoothEnabled;

  const BluetoothState({
    this.status = BluetoothStatus.initial,
    this.discoveredDevices = const [],
    this.connectedDevice,
    this.connectingDeviceId,
    this.errorMessage,
    this.lastMessage,
    this.selectedItemId,
    this.hasMoreLogs = false,
    this.permissionsGranted = false,
    this.bluetoothEnabled = false,
  });

  /// Creates a copy of this state with the given fields replaced.
  BluetoothState copyWith({
    BluetoothStatus? status,
    List<BleDevice>? discoveredDevices,
    BleDevice? connectedDevice,
    String? connectingDeviceId,
    String? errorMessage,
    BleMessage? lastMessage,
    String? selectedItemId,
    bool? hasMoreLogs,
    bool? permissionsGranted,
    bool? bluetoothEnabled,
    bool clearConnectedDevice = false,
    bool clearConnectingDeviceId = false,
    bool clearErrorMessage = false,
    bool clearLastMessage = false,
    bool clearSelectedItemId = false,
  }) {
    return BluetoothState(
      status: status ?? this.status,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: clearConnectedDevice ? null : (connectedDevice ?? this.connectedDevice),
      connectingDeviceId: clearConnectingDeviceId ? null : (connectingDeviceId ?? this.connectingDeviceId),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      lastMessage: clearLastMessage ? null : (lastMessage ?? this.lastMessage),
      selectedItemId: clearSelectedItemId ? null : (selectedItemId ?? this.selectedItemId),
      hasMoreLogs: hasMoreLogs ?? this.hasMoreLogs,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
    );
  }

  /// Whether the BLoC is currently scanning.
  bool get isScanning => status == BluetoothStatus.scanning;

  /// Whether a device is connected.
  bool get isConnected => status == BluetoothStatus.connected && connectedDevice != null;

  /// Whether currently connecting to a device.
  bool get isConnecting => status == BluetoothStatus.connecting;

  /// Whether ready to scan/connect (permissions granted, BT enabled).
  bool get isReady => status == BluetoothStatus.ready ||
                      status == BluetoothStatus.scanning ||
                      status == BluetoothStatus.connected ||
                      status == BluetoothStatus.connecting;

  @override
  List<Object?> get props => [
        status,
        discoveredDevices,
        connectedDevice,
        connectingDeviceId,
        errorMessage,
        lastMessage,
        selectedItemId,
        hasMoreLogs,
        permissionsGranted,
        bluetoothEnabled,
      ];

  @override
  String toString() {
    return 'BluetoothState(status: $status, devices: ${discoveredDevices.length}, '
        'connected: ${connectedDevice?.name ?? 'none'}, error: $errorMessage)';
  }
}
