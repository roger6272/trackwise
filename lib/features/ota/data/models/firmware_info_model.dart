import '../../domain/entities/firmware_info.dart';

/// Data model for [FirmwareInfo] with JSON serialization.
///
/// Parses `firmware/<channel>/latest.json` from Firebase Storage.
class FirmwareInfoModel extends FirmwareInfo {
  const FirmwareInfoModel({
    required super.version,
    required super.filePath,
    required super.sha256,
    required super.minAppVersion,
    required super.changelog,
    required super.releasedAt,
  });

  /// Creates a [FirmwareInfoModel] from a JSON map.
  ///
  /// Expected format (from `latest.json`):
  /// ```json
  /// {
  ///   "version": "2.1.0",
  ///   "file_path": "firmware/bins/v2.1.0.bin",
  ///   "sha256": "ab3f9c...",
  ///   "min_app_version": "1.0.0",
  ///   "changelog": "Bug fixes and improvements",
  ///   "released_at": "2026-03-28T12:00:00Z"
  /// }
  /// ```
  factory FirmwareInfoModel.fromJson(Map<String, dynamic> json) {
    return FirmwareInfoModel(
      version: json['version'] as String? ?? '0.0.0',
      filePath: json['file_path'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
      minAppVersion: json['min_app_version'] as String? ?? '1.0.0',
      changelog: json['changelog'] as String? ?? '',
      releasedAt: json['released_at'] != null
          ? DateTime.parse(json['released_at'] as String)
          : DateTime.now(),
    );
  }

  /// Converts this model to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'file_path': filePath,
      'sha256': sha256,
      'min_app_version': minAppVersion,
      'changelog': changelog,
      'released_at': releasedAt.toIso8601String(),
    };
  }
}
