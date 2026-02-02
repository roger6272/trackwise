import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../bluetooth/domain/entities/paired_device.dart';
import '../entities/user.dart';

/// Repository interface for user data operations.
///
/// Handles Firestore user document operations for multi-device sync support.
/// Separate from [AuthRepository] which handles Firebase Auth operations.
///
/// Key responsibilities:
/// - Sync sequence number management
/// - Paired devices list management
/// - User document data access
abstract class UserRepository {
  /// Gets the current authenticated user with full Firestore data.
  ///
  /// Combines Firebase Auth user info with Firestore user document data.
  /// Returns [AuthFailure] if not authenticated.
  /// Returns [ServerFailure] if Firestore operation fails.
  Future<Either<Failure, User>> getCurrentUser();

  /// Fetches the sync sequence number fresh from Firestore.
  ///
  /// CRITICAL: This method ALWAYS fetches directly from Firestore server,
  /// bypassing any cache. This is essential for multi-device sync because:
  /// - User may have synced from another app instance (phone + tablet)
  /// - Cached value could be stale, causing false conflicts
  ///
  /// Returns the current sync_sequence_no value (0 if never synced).
  /// Returns [AuthFailure] if not authenticated.
  /// Returns [ServerFailure] if Firestore operation fails.
  Future<Either<Failure, int>> fetchSyncSequenceFromServer();

  /// Updates sync state after successful sync.
  ///
  /// Called after device acknowledges sync_complete to update:
  /// - [syncSequenceNo]: The new sequence number (incremented by caller)
  /// - [lastSelectedDeviceItemId]: The selected item from the synced device
  ///
  /// Returns [AuthFailure] if not authenticated.
  /// Returns [ServerFailure] if Firestore operation fails.
  Future<Either<Failure, void>> updateSyncState({
    required int syncSequenceNo,
    required int lastSelectedDeviceItemId,
  });

  /// Adds a paired device to the user's device list.
  ///
  /// Called when a new device successfully completes handshake.
  /// Enforces maximum 10 devices per account.
  ///
  /// Returns [ValidationFailure] if device limit (10) would be exceeded.
  /// Returns [AuthFailure] if not authenticated.
  /// Returns [ServerFailure] if Firestore operation fails.
  Future<Either<Failure, void>> addPairedDevice(PairedDevice device);

  /// Removes a paired device from the user's device list.
  ///
  /// Called when user unpairs a device from settings.
  /// Note: This only removes from app's list; device still needs factory reset
  /// to actually unpair from the account.
  ///
  /// Returns [AuthFailure] if not authenticated.
  /// Returns [ServerFailure] if Firestore operation fails.
  Future<Either<Failure, void>> removePairedDevice(String deviceInstanceId);

  /// Renames a paired device in the user's device list.
  ///
  /// Returns [AuthFailure] if not authenticated.
  /// Returns [ServerFailure] if Firestore operation fails.
  /// Returns [ValidationFailure] if device not found.
  Future<Either<Failure, void>> updateDeviceName(
    String deviceInstanceId,
    String newName,
  );

  /// Completes onboarding and saves user preferences.
  ///
  /// [displayName] - User's name (optional).
  /// [primaryUseCase] - How the user plans to use the product.
  /// [referralSource] - How the user heard about the product (optional).
  /// [onboardingDevicePaired] - Whether the user paired a device during onboarding (optional).
  /// [onboardingItemCreated] - Whether the user created an item during onboarding (optional).
  ///
  /// Returns [AuthFailure] if not authenticated.
  /// Returns [ServerFailure] if Firestore operation fails.
  Future<Either<Failure, void>> completeOnboarding({
    String? displayName,
    required String primaryUseCase,
    String? referralSource,
    bool? onboardingDevicePaired,
    bool? onboardingItemCreated,
  });
}
