import 'package:equatable/equatable.dart';

import '../../../bluetooth/domain/entities/paired_device.dart';

/// Domain entity representing an authenticated user.
///
/// Contains authentication info from Firebase Auth plus sync state fields
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

  /// Global sync sequence number.
  ///
  /// Incremented on every successful sync with any device.
  /// Used for conflict detection: if device's sync_seq differs from app's,
  /// the app is source of truth and device needs override.
  /// Default: 0 (never synced)
  final int syncSequenceNo;

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

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
    this.syncSequenceNo = 0,
    this.lastSelectedDeviceItemId = -1,
    this.pairedDevices = const [],
  });

  /// Creates a copy with the given fields replaced.
  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? emailVerified,
    int? syncSequenceNo,
    int? lastSelectedDeviceItemId,
    List<PairedDevice>? pairedDevices,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      syncSequenceNo: syncSequenceNo ?? this.syncSequenceNo,
      lastSelectedDeviceItemId:
          lastSelectedDeviceItemId ?? this.lastSelectedDeviceItemId,
      pairedDevices: pairedDevices ?? this.pairedDevices,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        photoUrl,
        emailVerified,
        syncSequenceNo,
        lastSelectedDeviceItemId,
        pairedDevices,
      ];

  /// Check if user has a display name
  bool get hasDisplayName => displayName != null && displayName!.isNotEmpty;

  /// Check if user has a photo
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  /// Check if user has reached the maximum number of paired devices (10)
  bool get hasReachedDeviceLimit => pairedDevices.length >= 10;
}
