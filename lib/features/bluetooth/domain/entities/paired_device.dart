import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a physical Traxelos device paired to a user's account.
///
/// Each physical device has a unique [deviceInstanceId] generated on first boot.
/// The ID is regenerated on factory reset, allowing the same physical device
/// to be re-paired as a "new" device after reset.
///
/// Used for:
/// - Tracking which devices are paired to an account
/// - Managing device list in settings
/// - Conflict detection during sync (via device_instance_id comparison)
class PairedDevice extends Equatable {
  /// Unique identifier for this physical device.
  ///
  /// Generated as UUID on device's first boot, stored in NVS.
  /// Regenerated on factory reset.
  final String deviceInstanceId;

  /// User-friendly name for this device.
  ///
  /// Defaults to "Traxelos One" on first pairing.
  /// Can be customized by user in settings.
  final String deviceName;

  /// When this device was first paired to the account.
  final DateTime pairedAt;

  const PairedDevice({
    required this.deviceInstanceId,
    required this.deviceName,
    required this.pairedAt,
  });

  /// Creates a copy with the given fields replaced.
  PairedDevice copyWith({
    String? deviceInstanceId,
    String? deviceName,
    DateTime? pairedAt,
  }) {
    return PairedDevice(
      deviceInstanceId: deviceInstanceId ?? this.deviceInstanceId,
      deviceName: deviceName ?? this.deviceName,
      pairedAt: pairedAt ?? this.pairedAt,
    );
  }

  /// Creates a PairedDevice from a Firestore map.
  factory PairedDevice.fromFirestore(Map<String, dynamic> data) {
    return PairedDevice(
      deviceInstanceId: data['device_instance_id'] as String? ?? '',
      deviceName: data['device_name'] as String? ?? 'Traxelos One',
      pairedAt: _parseTimestamp(data['paired_at']),
    );
  }

  /// Converts this PairedDevice to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'device_instance_id': deviceInstanceId,
      'device_name': deviceName,
      'paired_at': Timestamp.fromDate(pairedAt),
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

  @override
  List<Object?> get props => [deviceInstanceId, deviceName, pairedAt];

  @override
  String toString() {
    return 'PairedDevice(deviceInstanceId: $deviceInstanceId, '
        'deviceName: $deviceName, pairedAt: $pairedAt)';
  }
}
