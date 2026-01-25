import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';

/// Base class for sync-specific failures.
///
/// All sync failures extend the base [Failure] class and are used
/// during multi-device sync operations.
abstract class SyncFailure extends Failure {
  const SyncFailure(super.message);
}

/// No internet connection available.
///
/// Sync operations require internet to fetch fresh sync_seq from Firestore.
/// User should be shown a message to check their connection.
class NoInternetFailure extends SyncFailure {
  const NoInternetFailure([String message = 'Internet connection required to sync.'])
      : super(message);
}

/// Device is paired to a different Firebase account.
///
/// User must factory reset the device to pair it to their account.
/// Cannot sync with devices paired to other users.
class WrongAccountFailure extends SyncFailure {
  const WrongAccountFailure([
    String message = 'This device is paired to another account. Factory reset required.',
  ]) : super(message);
}

/// Maximum device limit (10) has been reached.
///
/// User must unpair a device before adding a new one.
class DeviceLimitFailure extends SyncFailure {
  const DeviceLimitFailure([
    String message = 'Maximum 10 devices allowed per account.',
  ]) : super(message);
}

/// Sync sequence mismatch detected - app data should override device.
///
/// Contains both sequence numbers so the UI can show appropriate
/// conflict resolution options.
///
/// When this failure is returned, the UI should:
/// 1. Show conflict dialog explaining the situation
/// 2. Allow user to confirm override (proceed with app data)
/// 3. Allow user to cancel (disconnect from device)
class SyncConflictFailure extends SyncFailure {
  /// Device's current sync sequence number.
  final int? deviceSyncSeq;

  /// App's current sync sequence number (from Firestore).
  final int appSyncSeq;

  const SyncConflictFailure({
    this.deviceSyncSeq,
    required this.appSyncSeq,
    String message = 'Device needs to be updated to match your app.',
  }) : super(message);

  @override
  List<Object> get props => [message, appSyncSeq, if (deviceSyncSeq != null) deviceSyncSeq!];

  @override
  String toString() => 'SyncConflictFailure(message: $message, '
      'deviceSyncSeq: $deviceSyncSeq, appSyncSeq: $appSyncSeq)';
}

/// Firestore update failed after device acknowledged sync.
///
/// This is a critical failure - the device has the new sync_seq but
/// Firestore doesn't. Retry was attempted but failed.
/// On reconnect, conflict will be detected and user must resolve.
class FirestoreUpdateFailure extends SyncFailure {
  const FirestoreUpdateFailure([
    String message = 'Sync incomplete. Please ensure internet connection and try again.',
  ]) : super(message);
}

/// Too many items to sync (maximum 100).
///
/// Device has 100 item slots (0-99). Both app and device enforce this limit.
/// User must delete some items before syncing.
class TooManyItemsFailure extends SyncFailure {
  /// Number of items the user has.
  final int itemCount;

  const TooManyItemsFailure({
    required this.itemCount,
    String message = 'Cannot sync more than 100 items.',
  }) : super(message);

  @override
  List<Object> get props => [message, itemCount];
}

/// Device did not acknowledge sync_complete command.
///
/// The device's sync_seq was not updated. On reconnect, it will
/// still be in sync (if it was before) and sync will proceed normally.
class SyncCompleteNotAcknowledgedFailure extends SyncFailure {
  const SyncCompleteNotAcknowledgedFailure([
    String message = 'Device did not confirm sync completion. Please try again.',
  ]) : super(message);
}

/// Override operation failed on the device.
///
/// This includes missing chunks or other device-side errors.
/// The device's sync_seq was NOT updated, so on reconnect conflict
/// will be detected again and user can retry the override.
class OverrideFailure extends SyncFailure {
  /// Device-reported error message.
  final String? deviceMessage;

  const OverrideFailure({
    this.deviceMessage,
    String message = 'Override failed. Please try again.',
  }) : super(message);

  @override
  List<Object> get props => [message, if (deviceMessage != null) deviceMessage!];
}

/// Generic BLE error during sync operation.
///
/// Wraps lower-level BLE errors for sync context.
/// Typically caused by disconnect or timeout during sync.
class BleSyncFailure extends SyncFailure {
  const BleSyncFailure([String message = 'Bluetooth error during sync.'])
      : super(message);
}

/// User not authenticated.
///
/// Cannot sync without a logged-in user.
class NotAuthenticatedFailure extends SyncFailure {
  const NotAuthenticatedFailure([String message = 'Please log in to sync.'])
      : super(message);
}
