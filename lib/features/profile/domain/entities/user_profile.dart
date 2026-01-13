import 'package:equatable/equatable.dart';

/// Domain entity representing a user's profile.
///
/// Contains user information and metadata for the Profile feature.
/// Used for profile management and GDPR data export/deletion.
class UserProfile extends Equatable {
  /// Firebase UID of the user
  final String userId;

  /// User's email address
  final String email;

  /// User's display name (optional)
  final String? displayName;

  /// User's photo URL (optional)
  final String? photoUrl;

  /// When the account was created
  final DateTime createdAt;

  /// Last login timestamp
  final DateTime lastLogin;

  const UserProfile({
    required this.userId,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    required this.lastLogin,
  });

  /// Creates a copy of this profile with the given fields replaced.
  UserProfile copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        email,
        displayName,
        photoUrl,
        createdAt,
        lastLogin,
      ];

  @override
  String toString() {
    return 'UserProfile(userId: $userId, email: $email, displayName: $displayName, '
        'photoUrl: $photoUrl, createdAt: $createdAt, lastLogin: $lastLogin)';
  }
}
