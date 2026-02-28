import 'package:equatable/equatable.dart';
import '../../domain/entities/ble_device.dart';

enum DeviceSyncStatus { handshaking, syncing, synced, conflict, staleClaim, setup, wrongAccount }

class DeviceConnectionState extends Equatable {
  final BleDevice device;
  final DeviceSyncStatus syncStatus;
  final String? selectedItemId;
  final bool isOverriding;
  final bool hasMoreLogs;
  final int? conflictAppSyncSeq;
  final int? conflictDeviceSyncSeq;

  bool get isOnline => syncStatus == DeviceSyncStatus.synced;

  const DeviceConnectionState({
    required this.device,
    required this.syncStatus,
    this.selectedItemId,
    this.isOverriding = false,
    this.hasMoreLogs = false,
    this.conflictAppSyncSeq,
    this.conflictDeviceSyncSeq,
  });

  DeviceConnectionState copyWith({
    BleDevice? device,
    DeviceSyncStatus? syncStatus,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    bool? isOverriding,
    bool? hasMoreLogs,
    int? conflictAppSyncSeq,
    int? conflictDeviceSyncSeq,
    bool clearConflict = false,
  }) {
    return DeviceConnectionState(
      device: device ?? this.device,
      syncStatus: syncStatus ?? this.syncStatus,
      selectedItemId: clearSelectedItemId ? null : (selectedItemId ?? this.selectedItemId),
      isOverriding: isOverriding ?? this.isOverriding,
      hasMoreLogs: hasMoreLogs ?? this.hasMoreLogs,
      conflictAppSyncSeq: clearConflict ? null : (conflictAppSyncSeq ?? this.conflictAppSyncSeq),
      conflictDeviceSyncSeq: clearConflict ? null : (conflictDeviceSyncSeq ?? this.conflictDeviceSyncSeq),
    );
  }

  @override
  List<Object?> get props => [device, syncStatus, selectedItemId, isOverriding, hasMoreLogs, conflictAppSyncSeq, conflictDeviceSyncSeq];
}

bool isItemEditable(String? claimedBy, Map<String, DeviceConnectionState> connectedDevices) {
  if (claimedBy == null) return true;
  final device = connectedDevices[claimedBy];
  if (device == null) return false;
  return device.isOnline;
}
