import 'package:equatable/equatable.dart';
import '../../domain/entities/ble_device.dart';

enum DeviceSyncStatus { handshaking, syncing, synced, staleClaim, setup, wrongAccount }

class DeviceConnectionState extends Equatable {
  final BleDevice device;
  final DeviceSyncStatus syncStatus;
  final String? selectedItemId;
  final bool isOverriding;
  final bool hasMoreLogs;

  /// Battery level percentage (0-100), null if not available.
  /// Only populated when the device supports Battery Service (0x180F).
  final int? batteryLevel;

  /// Firmware version reported by device during handshake (e.g., "1.5.0").
  /// Used by OTA bloc to check for available firmware updates.
  final String? firmwareVersion;

  /// Negotiated BLE MTU payload size in bytes (e.g., 509).
  /// Defaults to [BluetoothConstants.defaultMtuLimit] until MTU negotiation completes.
  final int? negotiatedMtu;

  bool get isOnline => syncStatus == DeviceSyncStatus.synced;

  const DeviceConnectionState({
    required this.device,
    required this.syncStatus,
    this.selectedItemId,
    this.isOverriding = false,
    this.hasMoreLogs = false,
    this.batteryLevel,
    this.firmwareVersion,
    this.negotiatedMtu,
  });

  DeviceConnectionState copyWith({
    BleDevice? device,
    DeviceSyncStatus? syncStatus,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    bool? isOverriding,
    bool? hasMoreLogs,
    int? batteryLevel,
    String? firmwareVersion,
    int? negotiatedMtu,
  }) {
    return DeviceConnectionState(
      device: device ?? this.device,
      syncStatus: syncStatus ?? this.syncStatus,
      selectedItemId: clearSelectedItemId ? null : (selectedItemId ?? this.selectedItemId),
      isOverriding: isOverriding ?? this.isOverriding,
      hasMoreLogs: hasMoreLogs ?? this.hasMoreLogs,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      negotiatedMtu: negotiatedMtu ?? this.negotiatedMtu,
    );
  }

  @override
  List<Object?> get props => [device, syncStatus, selectedItemId, isOverriding, hasMoreLogs, batteryLevel, firmwareVersion, negotiatedMtu];
}

bool isItemEditable(String? claimedBy, Map<String, DeviceConnectionState> connectedDevices) {
  if (claimedBy == null) return true;
  final device = connectedDevices[claimedBy];
  if (device == null) return false;
  return device.isOnline;
}
