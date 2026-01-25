import 'package:equatable/equatable.dart';

/// Sync status returned by device during handshake.
///
/// - [inSync]: Device sync_seq matches app sync_seq - proceed with normal sync
/// - [conflict]: Device sync_seq differs from app sync_seq - app is source of truth
/// - [wrongAccount]: Device is paired to a different Firebase uid
enum SyncStatus {
  /// Device is in sync with app - proceed with normal sync (device is SOT)
  inSync,

  /// Sync sequence mismatch - app data should override device
  conflict,

  /// Device is paired to a different account - cannot sync
  wrongAccount,
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

  /// Device's current sync sequence number.
  /// Only present when status is [SyncStatus.conflict].
  final int? deviceSyncSeq;

  const HandshakeResult({
    required this.status,
    required this.deviceInstanceId,
    this.deviceSyncSeq,
  });

  /// Creates a HandshakeResult from device JSON response.
  ///
  /// Expected formats:
  /// - `{"status":"in_sync","device_instance_id":"uuid"}`
  /// - `{"status":"conflict","device_seq":40,"device_instance_id":"uuid"}`
  /// - `{"status":"wrong_account","device_instance_id":"uuid"}`
  factory HandshakeResult.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String?;
    SyncStatus status;

    switch (statusStr) {
      case 'in_sync':
        status = SyncStatus.inSync;
        break;
      case 'wrong_account':
        status = SyncStatus.wrongAccount;
        break;
      case 'conflict':
      default:
        status = SyncStatus.conflict;
    }

    return HandshakeResult(
      status: status,
      deviceInstanceId: json['device_instance_id'] as String? ?? '',
      deviceSyncSeq: json['device_seq'] as int?,
    );
  }

  @override
  List<Object?> get props => [status, deviceInstanceId, deviceSyncSeq];

  @override
  String toString() {
    return 'HandshakeResult(status: $status, deviceInstanceId: $deviceInstanceId, '
        'deviceSyncSeq: $deviceSyncSeq)';
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

/// Result of sync_complete command sent to device.
///
/// Confirms that the device has stored the new sync sequence number.
class SyncCompleteResult extends Equatable {
  /// Status returned by device.
  /// - 'seq_updated': Device stored the new sync_seq
  final String status;

  const SyncCompleteResult({
    required this.status,
  });

  /// Whether the sync_seq was successfully stored.
  bool get isSuccess => status == 'seq_updated';

  /// Creates a SyncCompleteResult from device JSON response.
  ///
  /// Expected format: `{"status":"seq_updated"}`
  factory SyncCompleteResult.fromJson(Map<String, dynamic> json) {
    return SyncCompleteResult(
      status: json['status'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [status];

  @override
  String toString() {
    return 'SyncCompleteResult(status: $status)';
  }
}
