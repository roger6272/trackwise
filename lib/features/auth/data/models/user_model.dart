import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../../../bluetooth/domain/entities/paired_device.dart';
import '../../domain/entities/user.dart';

/// Data model for User that handles Firebase Auth and Firestore conversion.
///
/// Combines data from:
/// - Firebase Auth (id, email, displayName, photoUrl, emailVerified)
/// - Firestore users collection (lastSelectedDeviceItemId, pairedDevices)
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    super.displayName,
    super.photoUrl,
    super.emailVerified,
    super.lastSelectedDeviceItemId,
    super.pairedDevices,
    super.onboardingCompleted,
    super.onboardingDevicePaired,
    super.onboardingItemCreated,
    super.primaryUseCase,
    super.referralSource,
  });

  /// Create UserModel from Firebase Auth User.
  ///
  /// Note: This only populates Firebase Auth fields. Firestore fields
  /// (lastSelectedDeviceItemId, pairedDevices) will have default values.
  /// Use [fromFirebaseUserAndFirestore] for complete data.
  factory UserModel.fromFirebaseUser(firebase.User firebaseUser) {
    return UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
      emailVerified: firebaseUser.emailVerified,
    );
  }

  /// Create UserModel from Firebase Auth User and Firestore document data.
  ///
  /// Use this when you have both Firebase Auth user and Firestore data available.
  factory UserModel.fromFirebaseUserAndFirestore(
    firebase.User firebaseUser,
    Map<String, dynamic>? firestoreData,
  ) {
    final data = firestoreData ?? {};

    // Parse paired_devices array
    final pairedDevicesRaw = data['paired_devices'] as List<dynamic>? ?? [];
    final pairedDevices = pairedDevicesRaw
        .map((e) => PairedDevice.fromFirestore(e as Map<String, dynamic>))
        .toList();

    // Default to false - user must complete onboarding to mark it true
    final onboardingCompleted = data['onboarding_completed'] as bool? ?? false;

    return UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
      emailVerified: firebaseUser.emailVerified,
      lastSelectedDeviceItemId:
          data['last_selected_device_item_id'] as int? ?? -1,
      pairedDevices: pairedDevices,
      onboardingCompleted: onboardingCompleted,
      onboardingDevicePaired:
          data['onboarding_device_paired'] as bool? ?? false,
      onboardingItemCreated:
          data['onboarding_item_created'] as bool? ?? false,
      primaryUseCase: data['primary_use_case'] as String?,
      referralSource: data['referral_source'] as String?,
    );
  }

  /// Create UserModel from Firestore document.
  ///
  /// Use this when you only have Firestore data (e.g., for user lookup by ID).
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse paired_devices array
    final pairedDevicesRaw = data['paired_devices'] as List<dynamic>? ?? [];
    final pairedDevices = pairedDevicesRaw
        .map((e) => PairedDevice.fromFirestore(e as Map<String, dynamic>))
        .toList();

    // Default to false - user must complete onboarding to mark it true
    final onboardingCompleted = data['onboarding_completed'] as bool? ?? false;

    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['display_name'] as String?,
      photoUrl: data['photo_url'] as String?,
      emailVerified: data['email_verified'] as bool? ?? false,
      lastSelectedDeviceItemId:
          data['last_selected_device_item_id'] as int? ?? -1,
      pairedDevices: pairedDevices,
      onboardingCompleted: onboardingCompleted,
      onboardingDevicePaired:
          data['onboarding_device_paired'] as bool? ?? false,
      onboardingItemCreated:
          data['onboarding_item_created'] as bool? ?? false,
      primaryUseCase: data['primary_use_case'] as String?,
      referralSource: data['referral_source'] as String?,
    );
  }

  /// Convert to Firestore-compatible map.
  ///
  /// Note: Only includes Firestore-specific fields. Firebase Auth fields
  /// (email, displayName, etc.) are managed by Firebase Auth, not Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'last_selected_device_item_id': lastSelectedDeviceItemId,
      'paired_devices': pairedDevices.map((d) => d.toFirestore()).toList(),
      'onboarding_completed': onboardingCompleted,
      'onboarding_device_paired': onboardingDevicePaired,
      'onboarding_item_created': onboardingItemCreated,
      if (primaryUseCase != null) 'primary_use_case': primaryUseCase,
      if (referralSource != null) 'referral_source': referralSource,
    };
  }

  /// Convert to domain entity.
  User toEntity() {
    return User(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      emailVerified: emailVerified,
      lastSelectedDeviceItemId: lastSelectedDeviceItemId,
      pairedDevices: pairedDevices,
      onboardingCompleted: onboardingCompleted,
      onboardingDevicePaired: onboardingDevicePaired,
      onboardingItemCreated: onboardingItemCreated,
      primaryUseCase: primaryUseCase,
      referralSource: referralSource,
    );
  }

  /// Creates a copy with the given fields replaced.
  @override
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? emailVerified,
    int? lastSelectedDeviceItemId,
    List<PairedDevice>? pairedDevices,
    bool? onboardingCompleted,
    bool? onboardingDevicePaired,
    bool? onboardingItemCreated,
    String? primaryUseCase,
    String? referralSource,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      lastSelectedDeviceItemId:
          lastSelectedDeviceItemId ?? this.lastSelectedDeviceItemId,
      pairedDevices: pairedDevices ?? this.pairedDevices,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingDevicePaired:
          onboardingDevicePaired ?? this.onboardingDevicePaired,
      onboardingItemCreated:
          onboardingItemCreated ?? this.onboardingItemCreated,
      primaryUseCase: primaryUseCase ?? this.primaryUseCase,
      referralSource: referralSource ?? this.referralSource,
    );
  }
}
