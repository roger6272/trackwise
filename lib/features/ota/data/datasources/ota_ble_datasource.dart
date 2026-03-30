import 'dart:typed_data';

/// Abstract interface for OTA BLE operations.
///
/// Handles sending OTA commands and firmware data to the device over BLE.
/// Uses the existing command/notify characteristics for control messages
/// and the dedicated OTA Data characteristic for binary chunks.
abstract class OtaBleDatasource {
  /// Sends the `ota_start` command to begin an OTA session.
  ///
  /// [expectedSize] is the firmware binary size in bytes.
  /// [expectedHash] is the SHA256 hash of the firmware binary.
  /// [version] is the firmware version string (e.g., "2.1.0").
  ///
  /// Throws on BLE write failure.
  Future<void> sendOtaStart({
    required int expectedSize,
    required String expectedHash,
    required String version,
  });

  /// Sends the `ota_end` command to finalize the transfer.
  ///
  /// Device will verify the received data against the SHA256 hash
  /// provided in `ota_start`.
  ///
  /// Throws on BLE write failure.
  Future<void> sendOtaEnd();

  /// Sends the `reboot` command to switch partitions and restart.
  ///
  /// Only accepted when the device is in VERIFIED state.
  ///
  /// Throws on BLE write failure.
  Future<void> sendReboot();

  /// Writes a chunk of firmware binary data to the OTA Data characteristic.
  ///
  /// Uses write-with-response for reliability.
  /// Chunk size should respect the negotiated MTU minus ATT overhead.
  ///
  /// Throws on BLE write failure.
  Future<void> writeOtaChunk(Uint8List chunk);

  /// Listens for OTA-related notification responses from the device.
  ///
  /// Emits parsed JSON maps from the notify characteristic.
  /// Expected responses include:
  /// - `{"status": "ota_ready"}`
  /// - `{"status": "ota_verified"}`
  /// - `{"status": "error", "cmd": "ota_start", "reason": "..."}`
  /// - `{"status": "error", "cmd": "ota_end", "reason": "hash_mismatch"}`
  Stream<Map<String, dynamic>> listenForOtaNotifications();
}
