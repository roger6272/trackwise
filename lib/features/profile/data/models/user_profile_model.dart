import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../../domain/entities/user_profile.dart';

/// Data model for UserProfile entity with Firestore serialization.
///
/// Extends the domain UserProfile entity and adds conversion methods for Firestore.
class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.userId,
    required super.email,
    super.displayName,
    super.photoUrl,
    required super.createdAt,
    required super.lastLogin,
  });

  /// Creates a UserProfileModel from a Firebase Auth User.
  ///
  /// Uses Firebase Auth user metadata for timestamps.
  factory UserProfileModel.fromFirebaseUser(firebase.User user) {
    return UserProfileModel(
      userId: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastLogin: user.metadata.lastSignInTime ?? DateTime.now(),
    );
  }

  /// Creates a UserProfileModel from a Firestore DocumentSnapshot.
  ///
  /// Maps Firestore field names to Dart property names.
  /// Provides sensible defaults for missing fields.
  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfileModel(
      userId: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['display_name'] as String?,
      photoUrl: data['photo_url'] as String?,
      createdAt: _parseTimestamp(data['created_at']),
      lastLogin: _parseTimestamp(data['last_login']),
    );
  }

  /// Converts this UserProfileModel to a Firestore-compatible map.
  ///
  /// Maps Dart property names to Firestore field names (snake_case).
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_login': lastLogin.millisecondsSinceEpoch,
    };
  }

  /// Parses a timestamp from Firestore.
  ///
  /// Handles both int milliseconds and Firestore Timestamp types.
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  /// Converts this model to a domain entity.
  UserProfile toEntity() => this;

  /// Creates a copy with updated fields.
  @override
  UserProfileModel copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserProfileModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
