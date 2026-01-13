import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_profile.dart';

/// Repository interface for Profile operations.
///
/// Defines the contract for profile data access. The data layer will implement
/// this interface to provide concrete implementations using Firebase.
///
/// All methods return Either<Failure, T> for type-safe error handling.
abstract class ProfileRepository {
  /// Fetches the current user's profile.
  ///
  /// Returns:
  /// - Right(UserProfile): Profile found
  /// - Left(AuthFailure): User not authenticated
  /// - Left(ServerFailure): Firestore query failed
  Future<Either<Failure, UserProfile>> getProfile();

  /// Updates the current user's profile.
  ///
  /// Parameters:
  /// - [displayName]: New display name (optional)
  /// - [photoUrl]: New photo URL (optional)
  ///
  /// Returns:
  /// - Right(UserProfile): Updated profile
  /// - Left(AuthFailure): User not authenticated
  /// - Left(ServerFailure): Firestore update failed
  Future<Either<Failure, UserProfile>> updateProfile({
    String? displayName,
    String? photoUrl,
  });

  /// Exports all user data as JSON string (GDPR compliance).
  ///
  /// Gathers data from all collections:
  /// - Profile information
  /// - Items
  /// - Event logs
  ///
  /// Returns:
  /// - Right(String): JSON string containing all user data
  /// - Left(AuthFailure): User not authenticated
  /// - Left(ServerFailure): Data export failed
  Future<Either<Failure, String>> exportUserData();

  /// Deletes the user account and all associated data (GDPR compliance).
  ///
  /// Permanently deletes:
  /// - All items owned by the user
  /// - All event logs for the user
  /// - User profile document
  /// - Firebase Auth account
  ///
  /// This operation is irreversible.
  ///
  /// Returns:
  /// - Right(void): Account successfully deleted
  /// - Left(AuthFailure): User not authenticated or re-authentication required
  /// - Left(ServerFailure): Deletion failed
  Future<Either<Failure, void>> deleteAccount();
}
