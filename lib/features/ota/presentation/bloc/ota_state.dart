import 'package:equatable/equatable.dart';

import '../../domain/entities/firmware_info.dart';
import 'ota_device_status.dart';

/// Composite OTA state with per-device awareness and single active transfer.
class OtaBlocState extends Equatable {
  /// Per-device update awareness, keyed by deviceInstanceId.
  final Map<String, OtaDeviceStatus> deviceStatuses;

  /// The currently active OTA transfer (at most one at a time).
  final OtaTransferState? activeTransfer;

  const OtaBlocState({
    this.deviceStatuses = const {},
    this.activeTransfer,
  });

  /// Whether any device has an available update (not dismissed).
  bool get hasAvailableUpdates => deviceStatuses.values
      .any((status) => status is OtaDeviceUpdateAvailable);

  /// Number of devices with available updates.
  int get availableUpdateCount => deviceStatuses.values
      .where((status) => status is OtaDeviceUpdateAvailable)
      .length;

  /// Whether an OTA transfer is actively in progress.
  bool get isTransferInProgress {
    final transfer = activeTransfer;
    return transfer != null &&
        transfer is! OtaTransferComplete &&
        transfer is! OtaTransferError;
  }

  /// The deviceInstanceId of the device currently being updated, if any.
  String? get activeDeviceId => activeTransfer?.deviceInstanceId;

  OtaBlocState copyWith({
    Map<String, OtaDeviceStatus>? deviceStatuses,
    OtaTransferState? activeTransfer,
    bool clearActiveTransfer = false,
  }) {
    return OtaBlocState(
      deviceStatuses: deviceStatuses ?? this.deviceStatuses,
      activeTransfer:
          clearActiveTransfer ? null : (activeTransfer ?? this.activeTransfer),
    );
  }

  @override
  List<Object?> get props => [deviceStatuses, activeTransfer];
}

/// Base class for active OTA transfer states.
sealed class OtaTransferState extends Equatable {
  final String deviceInstanceId;
  final FirmwareInfo info;

  const OtaTransferState({
    required this.deviceInstanceId,
    required this.info,
  });

  @override
  List<Object?> get props => [deviceInstanceId, info];
}

/// Downloading firmware binary from cloud.
class OtaTransferDownloading extends OtaTransferState {
  final double progress;

  const OtaTransferDownloading({
    required super.deviceInstanceId,
    required super.info,
    required this.progress,
  });

  @override
  List<Object?> get props => [deviceInstanceId, info, progress];
}

/// Transferring firmware to device over BLE.
class OtaTransferTransferring extends OtaTransferState {
  final double progress;

  const OtaTransferTransferring({
    required super.deviceInstanceId,
    required super.info,
    required this.progress,
  });

  @override
  List<Object?> get props => [deviceInstanceId, info, progress];
}

/// Device is verifying the received firmware.
class OtaTransferVerifying extends OtaTransferState {
  const OtaTransferVerifying({
    required super.deviceInstanceId,
    required super.info,
  });
}

/// Device is rebooting with new firmware.
class OtaTransferRebooting extends OtaTransferState {
  const OtaTransferRebooting({
    required super.deviceInstanceId,
    required super.info,
  });
}

/// OTA transfer completed successfully.
class OtaTransferComplete extends OtaTransferState {
  final String newVersion;

  const OtaTransferComplete({
    required super.deviceInstanceId,
    required super.info,
    required this.newVersion,
  });

  @override
  List<Object?> get props => [deviceInstanceId, info, newVersion];
}

/// OTA transfer failed.
class OtaTransferError extends OtaTransferState {
  final String message;

  const OtaTransferError({
    required super.deviceInstanceId,
    required super.info,
    required this.message,
  });

  @override
  List<Object?> get props => [deviceInstanceId, info, message];
}
