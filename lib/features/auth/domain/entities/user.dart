import 'package:equatable/equatable.dart';

/// Domain entity representing an authenticated user.
class User extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
  });

  @override
  List<Object?> get props => [id, email, displayName, photoUrl, emailVerified];

  /// Check if user has a display name
  bool get hasDisplayName => displayName != null && displayName!.isNotEmpty;

  /// Check if user has a photo
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;
}
