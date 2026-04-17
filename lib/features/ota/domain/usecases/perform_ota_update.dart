import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

  /// Sends ota_abort to the device to cancel an in-progress OTA session.
  ///
  /// Best-effort: failures are logged but not propagated, since the device
  /// will timeout on its own after 30s of inactivity.
  Future<void> abort() async {
    final result = await _repository.sendOtaAbort();
    result.fold(
      (failure) => AppLogger.debug('OTA abort send failed (non-fatal): ${failure.message}'),
      (_) => AppLogger.debug('OTA: Sent ota_abort to device'),
    );
  }

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

    // ---- Step 1b: Verify download integrity ----
    final computedHash = sha256.convert(binaryData).toString();
    if (computedHash != firmwareInfo.sha256) {
      final expectedPrefix = firmwareInfo.sha256.length >= 8
          ? firmwareInfo.sha256.substring(0, 8)
          : firmwareInfo.sha256;
      AppLogger.error(
        'OTA: SHA256 mismatch — expected $expectedPrefix..., '
        'got ${computedHash.substring(0, 8)}...',
      );
      yield const OtaError(
        'Downloaded file is corrupted. Check your internet connection and try again.',
      );
      return;
    }
    AppLogger.debug('OTA: SHA256 verified');

    // ---- Step 2: Send ota_start and wait for ota_ready ----
    yield const OtaTransferring(0.0);

    // Start listening BEFORE sending the command to avoid race condition
    // (firmware may respond before we set up the listener)
    final readyFuture = _waitForNotification(
      expectedStatus: 'ota_ready',
      timeout: _responseTimeout,
    );

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

    final readyResult = await readyFuture;

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

    // ---- Step 5: Send ota_end and wait for ota_verified ----
    yield const OtaVerifying();
    AppLogger.debug('OTA: Sending ota_end');

    // Start listening BEFORE sending to avoid race condition
    final verifyFuture = _waitForNotification(
      expectedStatus: 'ota_verified',
      timeout: _responseTimeout,
    );

    final endResult = await _repository.sendOtaEnd();
    if (endResult.isLeft()) {
      final errorMsg = endResult.fold((f) => f.message, (_) => '');
      yield OtaError('Failed to send ota_end: $errorMsg');
      return;
    }

    // ---- Step 6: Wait for ota_verified ----
    AppLogger.debug('OTA: Waiting for ota_verified notification');

    final verifyResult = await verifyFuture;

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
            final reason = data['reason'] as String?;
            // Accept expected status, explicit error status, or
            // BleMessageType.error responses (which have reason but no status)
            return status == expectedStatus ||
                status == 'error' ||
                reason != null;
          })
          .first
          .timeout(timeout);

      final status = notification['status'] as String?;
      if (status == expectedStatus) {
        return null; // Success
      }

      // Error response from device — map to user-friendly messages
      final reason = notification['reason'] as String? ?? 'unknown';
      return _friendlyError(reason);
    } on TimeoutException {
      return 'Device not responding. Please try again.';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  String _friendlyError(String reason) {
    switch (reason) {
      case 'low_battery':
        return 'Battery too low to update. Please charge your device above 20% and try again.';
      case 'hash_mismatch':
        return 'The update file was corrupted during download. Check your internet connection and try again.';
      case 'write_failed':
        return 'The update could not be installed. This update may not be compatible with your device.';
      case 'timeout':
        return 'The device stopped responding. Move closer to your device and try again.';
      case 'disconnect':
        return 'Connection lost during update. Move closer to your device and try again.';
      case 'invalid_version':
        return 'Your device already has this software version.';
      case 'no_partition':
        return 'Your device does not support updates. Please contact support.';
      case 'already_in_progress':
        return 'An update is already in progress.';
      case 'not_receiving':
        return 'The device was not ready. Please wait a moment and try again.';
      default:
        return 'Update failed ($reason). Please try again later.';
    }
  }
}
