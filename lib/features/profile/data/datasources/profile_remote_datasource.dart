import '../models/user_profile_model.dart';

/// Remote data source interface for Profile operations.
///
/// Defines the contract for Firebase operations related to user profiles.
abstract class ProfileRemoteDataSource {
  /// Fetches the current user's profile.
  ///
  /// Throws [AuthException] if user not authenticated.
  /// Throws [ServerException] if Firestore query fails.
  Future<UserProfileModel> getProfile();

  /// Updates the current user's profile.
  ///
  /// Throws [AuthException] if user not authenticated.
  /// Throws [ServerException] if Firestore update fails.
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? photoUrl,
  });

  /// Exports all user data as JSON string.
  ///
  /// Throws [AuthException] if user not authenticated.
  /// Throws [ServerException] if export fails.
  Future<String> exportUserData();

  /// Deletes the user account and all associated data.
  ///
  /// Throws [AuthException] if user not authenticated.
  /// Throws [ServerException] if deletion fails.
  Future<void> deleteAccount();
}
