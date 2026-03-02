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
/// Sync operations require internet to verify account state from Firestore.
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

/// Device is uninitialized (factory reset or new device).
///
/// Device has no UID stored and needs setup. User must confirm
/// before items are transferred.
///
/// When this failure is returned, the UI should:
/// 1. Show setup dialog: "New device detected. Transfer your items?"
/// 2. Allow user to confirm (proceed with override to set up device)
/// 3. Allow user to cancel (disconnect, device stays empty)
class DeviceUninitializedFailure extends SyncFailure {
  /// Device instance ID (needed to add device after successful setup).
  final String deviceInstanceId;

  const DeviceUninitializedFailure({
    required this.deviceInstanceId,
    String message = 'New device detected.',
  }) : super(message);

  @override
  List<Object> get props => [message, deviceInstanceId];

  @override
  String toString() => 'DeviceUninitializedFailure(deviceInstanceId: $deviceInstanceId)';
}

/// Firestore update failed after successful device sync.
///
/// Retry was attempted but failed. User should ensure internet connection.
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

/// Override operation failed on the device.
///
/// This includes missing chunks or other device-side errors.
/// User can retry the override on reconnect.
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
