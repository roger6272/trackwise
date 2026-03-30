import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/firmware_info.dart';

/// Repository interface for OTA firmware update operations.
///
/// Delegates to remote (Firebase) and BLE datasources.
/// Returns Either<Failure, T> for type-safe error handling.
abstract class OtaRepository {
  // ============================================================
  // REMOTE (Firebase)
  // ============================================================

  /// Fetches the latest available firmware info from Firebase Storage.
  ///
  /// Returns:
  /// - Right(FirmwareInfo): Latest firmware metadata
  /// - Left(ServerFailure): Download or parse failed
  Future<Either<Failure, FirmwareInfo>> fetchLatestFirmwareInfo();

  /// Fetches the minimum required firmware version from Remote Config.
  ///
  /// Falls back to hardcoded "1.0.0" on failure.
  ///
  /// Returns:
  /// - Right(String): Minimum firmware version string
  /// - Left(ServerFailure): Fetch failed (unlikely due to fallback)
  Future<Either<Failure, String>> fetchMinFirmwareVersion();

  /// Downloads the firmware binary from Firebase Storage.
  ///
  /// [filePath] is the path in Firebase Storage.
  /// [onProgress] reports download progress from 0.0 to 1.0.
  ///
  /// Returns:
  /// - Right(List<int>): Raw firmware binary bytes
  /// - Left(ServerFailure): Download failed
  Future<Either<Failure, List<int>>> downloadFirmwareBinary(
    String filePath, {
    void Function(double progress)? onProgress,
  });

  // ============================================================
  // BLE (Device Communication)
  // ============================================================

  /// Sends the `ota_start` command to the device.
  ///
  /// Returns:
  /// - Right(void): Command sent
  /// - Left(BluetoothFailure): BLE write failed
  Future<Either<Failure, void>> sendOtaStart({
    required int expectedSize,
    required String expectedHash,
    required String version,
  });

  /// Sends the `ota_end` command to the device.
  ///
  /// Returns:
  /// - Right(void): Command sent
  /// - Left(BluetoothFailure): BLE write failed
  Future<Either<Failure, void>> sendOtaEnd();

  /// Sends the `reboot` command to the device.
  ///
  /// Returns:
  /// - Right(void): Command sent
  /// - Left(BluetoothFailure): BLE write failed
  Future<Either<Failure, void>> sendReboot();

  /// Writes a firmware chunk to the OTA Data characteristic.
  ///
  /// Returns:
  /// - Right(void): Chunk written
  /// - Left(BluetoothFailure): BLE write failed
  Future<Either<Failure, void>> writeOtaChunk(Uint8List chunk);

  /// Listens for OTA notification responses from the device.
  ///
  /// Returns a stream of parsed notification maps.
  Stream<Map<String, dynamic>> listenForOtaNotifications();
}
