import 'dart:async';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import '../../../../core/utils/bluetooth_constants.dart';
import '../../../../core/utils/logger.dart';
import '../entities/firmware_info.dart';
import '../entities/ota_state.dart';
import '../repositories/ota_repository.dart';

/// Use case that orchestrates the full OTA firmware update flow.
///
/// Steps:
/// 1. Download firmware binary from Firebase Storage
/// 2. Send `ota_start` command with size and SHA256
/// 3. Wait for `ota_ready` notification
/// 4. Chunk binary using negotiated MTU, send chunks with write-with-response
/// 5. Send `ota_end` command
/// 6. Wait for `ota_verified` notification
/// 7. Send `reboot` command
///
/// Emits [OtaState] progress updates via a stream.
///
/// Note: Sync before OTA is the caller's responsibility (BLoC/presentation layer)
/// to keep this use case focused on the OTA transfer itself.
@lazySingleton
class PerformOtaUpdateUseCase {
  final OtaRepository _repository;

  /// Timeout for waiting on device responses (ota_ready, ota_verified).
  static const Duration _responseTimeout = Duration(seconds: 30);

  PerformOtaUpdateUseCase(this._repository);

  /// Executes the OTA update flow, emitting [OtaState] updates.
  ///
  /// [firmwareInfo] is the metadata for the firmware to install.
  /// [negotiatedMtu] is the BLE MTU size negotiated on connect.
  ///
  /// The returned stream emits progress states and completes on success or error.
  /// The caller can cancel by cancelling the stream subscription.
  Stream<OtaState> execute({
    required FirmwareInfo firmwareInfo,
    required int negotiatedMtu,
  }) async* {
    // ---- Step 1: Download firmware binary ----
    yield const OtaDownloading(0.0);
    AppLogger.debug('OTA: Downloading firmware v${firmwareInfo.version}');

    final downloadResult = await _repository.downloadFirmwareBinary(
      firmwareInfo.filePath,
      onProgress: (progress) {
        // Note: progress callbacks can't yield from inside a callback,
        // so download progress is reported as 0 → 1 in discrete steps.
      },
    );

    final binaryData = downloadResult.fold(
      (failure) => null,
      (data) => data,
    );

    if (binaryData == null) {
      final errorMsg = downloadResult.fold(
        (f) => f.message,
        (_) => 'Unknown error',
      );
      yield OtaError('Download failed: $errorMsg');
      return;
    }

    yield const OtaDownloading(1.0);
    AppLogger.debug('OTA: Downloaded ${binaryData.length} bytes');

    // ---- Step 2: Send ota_start ----
    yield const OtaTransferring(0.0);

    final startResult = await _repository.sendOtaStart(
      expectedSize: binaryData.length,
      expectedHash: firmwareInfo.sha256,
      version: firmwareInfo.version,
    );

    if (startResult.isLeft()) {
      final errorMsg = startResult.fold((f) => f.message, (_) => '');
      yield OtaError('Failed to send ota_start: $errorMsg');
      return;
    }

    // ---- Step 3: Wait for ota_ready ----
    AppLogger.debug('OTA: Waiting for ota_ready notification');

    final readyResult = await _waitForNotification(
      expectedStatus: 'ota_ready',
      timeout: _responseTimeout,
    );

    if (readyResult != null) {
      yield OtaError(readyResult);
      return;
    }

    // ---- Step 4: Send firmware chunks ----
    AppLogger.debug('OTA: Sending firmware chunks (MTU: $negotiatedMtu)');

    final chunkSize = negotiatedMtu - BluetoothConstants.attOverhead;
    final totalChunks = (binaryData.length / chunkSize).ceil();

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize).clamp(0, binaryData.length);
      final chunk = Uint8List.fromList(binaryData.sublist(start, end));

      final chunkResult = await _repository.writeOtaChunk(chunk);
      if (chunkResult.isLeft()) {
        final errorMsg = chunkResult.fold((f) => f.message, (_) => '');
        yield OtaError('Chunk write failed at $i/$totalChunks: $errorMsg');
        return;
      }

      // Report progress
      final progress = (i + 1) / totalChunks;
      yield OtaTransferring(progress);

      if ((i + 1) % 50 == 0 || i == totalChunks - 1) {
        AppLogger.debug('OTA: Sent chunk ${i + 1}/$totalChunks (${(progress * 100).toInt()}%)');
      }
    }

    // ---- Step 5: Send ota_end ----
    yield const OtaVerifying();
    AppLogger.debug('OTA: Sending ota_end');

    final endResult = await _repository.sendOtaEnd();
    if (endResult.isLeft()) {
      final errorMsg = endResult.fold((f) => f.message, (_) => '');
      yield OtaError('Failed to send ota_end: $errorMsg');
      return;
    }

    // ---- Step 6: Wait for ota_verified ----
    AppLogger.debug('OTA: Waiting for ota_verified notification');

    final verifyResult = await _waitForNotification(
      expectedStatus: 'ota_verified',
      timeout: _responseTimeout,
    );

    if (verifyResult != null) {
      yield OtaError(verifyResult);
      return;
    }

    // ---- Step 7: Send reboot ----
    yield const OtaRebooting();
    AppLogger.debug('OTA: Sending reboot');

    final rebootResult = await _repository.sendReboot();
    if (rebootResult.isLeft()) {
      final errorMsg = rebootResult.fold((f) => f.message, (_) => '');
      yield OtaError('Failed to send reboot: $errorMsg');
      return;
    }

    yield const OtaComplete();
    AppLogger.debug('OTA: Update complete, device is rebooting');
  }

  /// Waits for a specific OTA notification status from the device.
  ///
  /// Returns null on success, or an error message string on failure/timeout.
  Future<String?> _waitForNotification({
    required String expectedStatus,
    required Duration timeout,
  }) async {
    try {
      final notification = await _repository
          .listenForOtaNotifications()
          .where((data) {
            final status = data['status'] as String?;
            // Accept expected status OR error responses
            return status == expectedStatus ||
                status == 'error';
          })
          .first
          .timeout(timeout);

      final status = notification['status'] as String?;
      if (status == expectedStatus) {
        return null; // Success
      }

      // Error response from device
      final reason = notification['reason'] as String? ?? 'unknown';
      final cmd = notification['cmd'] as String? ?? 'unknown';
      return 'Device error ($cmd): $reason';
    } on TimeoutException {
      return 'Timed out waiting for $expectedStatus (${timeout.inSeconds}s)';
    } catch (e) {
      return 'Error waiting for $expectedStatus: $e';
    }
  }
}
