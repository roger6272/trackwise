import 'package:equatable/equatable.dart';

/// Sync status returned by device during handshake.
///
/// - [inSync]: Device is paired to this account - proceed with normal sync
/// - [wrongAccount]: Device is paired to a different Firebase uid
/// - [uninitialized]: Device has no UID - needs setup (factory reset or new device)
enum SyncStatus {
  /// Device is in sync with app - proceed with normal sync (device is SOT)
  inSync,

  /// Device is paired to a different account - cannot sync
  wrongAccount,

  /// Device has no UID - needs setup (factory reset or new device)
  /// User must confirm before items are transferred
  uninitialized,
}

/// Result of handshake command sent to device.
///
/// Contains the sync status and device information needed to determine
/// the appropriate sync flow (normal sync vs override).
class HandshakeResult extends Equatable {
  /// Sync status returned by device.
  final SyncStatus status;

  /// Unique identifier for this physical device.
  /// Generated as UUID on device's first boot, regenerated on factory reset.
  final String deviceInstanceId;

  /// BLE protocol version reported by device.
  final int? protocolVersion;

  /// Firmware version string reported by device (e.g. "1.5.0").
  final String? firmwareVersion;

  const HandshakeResult({
    required this.status,
    required this.deviceInstanceId,
    this.protocolVersion,
    this.firmwareVersion,
  });

  /// Creates a HandshakeResult from device JSON response.
  ///
  /// Expected formats:
  /// - `{"status":"in_sync","device_instance_id":"uuid"}`
  /// - `{"status":"wrong_account","device_instance_id":"uuid"}`
  /// - `{"status":"uninitialized","device_instance_id":"uuid"}`
  factory HandshakeResult.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String?;
    SyncStatus status;

    switch (statusStr) {
      case 'wrong_account':
        status = SyncStatus.wrongAccount;
        break;
      case 'uninitialized':
        status = SyncStatus.uninitialized;
        break;
      case 'in_sync':
      default:
        status = SyncStatus.inSync;
    }

    return HandshakeResult(
      status: status,
      deviceInstanceId: json['device_instance_id'] as String? ?? '',
      protocolVersion: json['protocol_version'] as int?,
      firmwareVersion: json['firmware_version'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        status,
        deviceInstanceId,
        protocolVersion,
        firmwareVersion,
      ];

  @override
  String toString() {
    return 'HandshakeResult(status: $status, deviceInstanceId: $deviceInstanceId, '
        'protocolVersion: $protocolVersion, firmwareVersion: $firmwareVersion)';
  }
}

/// Result of override command sent to device.
///
/// Returned after sending override_start, override_chunk(s), and override_end.
class OverrideResult extends Equatable {
  /// Status returned by device.
  /// - 'override_complete': Override succeeded
  /// - 'error': Override failed
  final String status;

  /// Error message when status is 'error'.
  /// e.g., "missing_chunks" if chunks were lost
  final String? message;

  const OverrideResult({
    required this.status,
    this.message,
  });

  /// Whether the override completed successfully.
  bool get isSuccess => status == 'override_complete';

  /// Creates an OverrideResult from device JSON response.
  ///
  /// Expected formats:
  /// - `{"status":"override_complete"}`
  /// - `{"status":"error","message":"missing_chunks"}`
  factory OverrideResult.fromJson(Map<String, dynamic> json) {
    return OverrideResult(
      status: json['status'] as String? ?? 'error',
      message: json['message'] as String?,
    );
  }

  @override
  List<Object?> get props => [status, message];

  @override
  String toString() {
    return 'OverrideResult(status: $status, message: $message)';
  }
}
