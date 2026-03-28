import 'package:equatable/equatable.dart';

/// Metadata about the latest available firmware version.
///
/// Parsed from `firmware/latest.json` in Firebase Storage.
class FirmwareInfo extends Equatable {
  /// Firmware version string (e.g., "2.1.0").
  final String version;

  /// Path to the binary file in Firebase Storage (e.g., "firmware/bins/v2.1.0.bin").
  final String filePath;

  /// SHA256 hash of the binary file for integrity verification.
  final String sha256;

  /// Minimum app version required to install this firmware.
  final String minAppVersion;

  /// Human-readable changelog for display in the update UI.
  final String changelog;

  /// When this firmware version was published.
  final DateTime releasedAt;

  const FirmwareInfo({
    required this.version,
    required this.filePath,
    required this.sha256,
    required this.minAppVersion,
    required this.changelog,
    required this.releasedAt,
  });

  @override
  List<Object?> get props => [
        version,
        filePath,
        sha256,
        minAppVersion,
        changelog,
        releasedAt,
      ];

  @override
  String toString() =>
      'FirmwareInfo(version: $version, filePath: $filePath, minAppVersion: $minAppVersion)';
}
