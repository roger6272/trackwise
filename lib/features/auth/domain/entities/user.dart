import 'package:equatable/equatable.dart';

import '../../../bluetooth/domain/entities/paired_device.dart';

/// Domain entity representing an authenticated user.
///
/// Contains authentication info from Firebase Auth plus device-related fields
/// stored in the Firestore users collection for multi-device support.
class User extends Equatable {
  /// Firebase UID
  final String id;

  /// User's email address
  final String email;

  /// User's display name (optional)
  final String? displayName;

  /// User's photo URL (optional)
  final String? photoUrl;

  /// Whether email has been verified
  final bool emailVerified;

  /// The device_item_id of the last selected item on any device.
  ///
  /// Stored after each successful sync. Used during override to restore
  /// the selected item on a different device.
  /// Default: -1 (no item selected)
  final int lastSelectedDeviceItemId;

  /// List of physical devices paired to this account.
  ///
  /// Each device is identified by its device_instance_id (UUID).
  /// Maximum 10 devices per account.
  final List<PairedDevice> pairedDevices;

  /// Whether the user has completed onboarding.
  /// New users should be redirected to onboarding page.
  final bool onboardingCompleted;

  /// Whether the user paired a device during onboarding.
  final bool onboardingDevicePaired;

  /// Whether the user created an item during onboarding.
  final bool onboardingItemCreated;

  /// User's primary use case for the product.
  /// Collected during onboarding for product insights.
  final String? primaryUseCase;

  /// How the user heard about the product.
  /// Collected during onboarding for marketing insights.
  final String? referralSource;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
    this.lastSelectedDeviceItemId = -1,
    this.pairedDevices = const [],
    this.onboardingCompleted = false,
    this.onboardingDevicePaired = false,
    this.onboardingItemCreated = false,
    this.primaryUseCase,
    this.referralSource,
  });

  /// Creates a copy with the given fields replaced.
  User copyWith({
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
    return User(
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

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        photoUrl,
        emailVerified,
        lastSelectedDeviceItemId,
        pairedDevices,
        onboardingCompleted,
        onboardingDevicePaired,
        onboardingItemCreated,
        primaryUseCase,
        referralSource,
      ];

  /// Check if user has a display name
  bool get hasDisplayName => displayName != null && displayName!.isNotEmpty;

  /// Check if user has a photo
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  /// Check if user has reached the maximum number of paired devices (10)
  bool get hasReachedDeviceLimit => pairedDevices.length >= 10;
}
