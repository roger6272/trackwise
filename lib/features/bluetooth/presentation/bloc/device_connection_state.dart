import 'package:equatable/equatable.dart';
import '../../domain/entities/ble_device.dart';

enum DeviceSyncStatus { handshaking, syncing, synced, staleClaim, setup, wrongAccount }

class DeviceConnectionState extends Equatable {
  final BleDevice device;
  final DeviceSyncStatus syncStatus;
  final String? selectedItemId;
  final bool isOverriding;
  final bool hasMoreLogs;

  bool get isOnline => syncStatus == DeviceSyncStatus.synced;

  const DeviceConnectionState({
    required this.device,
    required this.syncStatus,
    this.selectedItemId,
    this.isOverriding = false,
    this.hasMoreLogs = false,
  });

  DeviceConnectionState copyWith({
    BleDevice? device,
    DeviceSyncStatus? syncStatus,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    bool? isOverriding,
    bool? hasMoreLogs,
  }) {
    return DeviceConnectionState(
      device: device ?? this.device,
      syncStatus: syncStatus ?? this.syncStatus,
      selectedItemId: clearSelectedItemId ? null : (selectedItemId ?? this.selectedItemId),
      isOverriding: isOverriding ?? this.isOverriding,
      hasMoreLogs: hasMoreLogs ?? this.hasMoreLogs,
    );
  }

  @override
  List<Object?> get props => [device, syncStatus, selectedItemId, isOverriding, hasMoreLogs];
}

bool isItemEditable(String? claimedBy, Map<String, DeviceConnectionState> connectedDevices) {
  if (claimedBy == null) return true;
  final device = connectedDevices[claimedBy];
  if (device == null) return false;
  return device.isOnline;
}
