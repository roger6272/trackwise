import '../models/firmware_info_model.dart';

/// Abstract interface for OTA remote data operations.
///
/// Handles fetching firmware metadata and version constraints
/// from Firebase Storage and Remote Config.
abstract class OtaRemoteDataSource {
  /// Fetches the latest firmware metadata from Firebase Storage.
  ///
  /// Downloads and parses `firmware/<channel>/latest.json`.
  ///
  /// Throws [Exception] if the download or parse fails.
  Future<FirmwareInfoModel> fetchLatestFirmwareInfo();

  /// Fetches the minimum required firmware version from Remote Config.
  ///
  /// Falls back to hardcoded "1.0.0" if Remote Config is unreachable.
  Future<String> fetchMinFirmwareVersion();

  /// Downloads the firmware binary from Firebase Storage.
  ///
  /// [filePath] is the path within Firebase Storage (e.g., "firmware/bins/v2.1.0.bin").
  /// [onProgress] reports download progress from 0.0 to 1.0.
  ///
  /// Returns the raw firmware binary bytes.
  ///
  /// Throws [Exception] if the download fails.
  Future<List<int>> downloadFirmwareBinary(
    String filePath, {
    void Function(double progress)? onProgress,
  });
}
