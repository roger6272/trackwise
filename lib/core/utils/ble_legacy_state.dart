import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'bluetooth_constants.dart';

/// Singleton state holder for BLE legacy operations.
///
/// Replaces FFAppState for the extracted BLE functions.
/// Holds pagination state for log syncing, selected item tracking,
/// and cached BLE characteristics to avoid redundant service discovery.
class BleLegacyState {
  // Singleton instance
  static final BleLegacyState _instance = BleLegacyState._internal();
  factory BleLegacyState() => _instance;
  BleLegacyState._internal();

  /// Current page for paginated log reading from device.
  /// Incremented when device reports hasMore=true, reset to 0 when done.
  int currentLogPage = 0;

  /// Currently selected/activated item ID from device.
  /// Updated when device sends prefs data with selected_id.
  String? isactivated;

  // ========== Cached BLE Characteristics ==========

  /// The currently connected device ID (for cache invalidation)
  String? _cachedDeviceId;

  /// Cached READ characteristic
  BluetoothCharacteristic? _readChar;

  /// Cached WRITE characteristic
  BluetoothCharacteristic? _writeChar;

  /// Gets cached characteristics or discovers them if needed.
  /// Returns a record with (readChar, writeChar).
  Future<({BluetoothCharacteristic readChar, BluetoothCharacteristic writeChar})>
      getCharacteristics(String deviceId) async {
    // If cache is valid for this device, return cached values
    if (_cachedDeviceId == deviceId && _readChar != null && _writeChar != null) {
      debugPrint('📋 Using cached BLE characteristics');
      return (readChar: _readChar!, writeChar: _writeChar!);
    }

    // Need to discover services
    debugPrint('🔍 Discovering BLE services (first time for this connection)');
    final device = BluetoothDevice.fromId(deviceId);
    final services = await device.discoverServices();

    // Find and cache characteristics
    for (final service in services) {
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == BluetoothConstants.readCharacteristicUUID.toLowerCase()) {
          _readChar = char;
        } else if (uuid == BluetoothConstants.writeCharacteristicUUID.toLowerCase()) {
          _writeChar = char;
        }
      }
    }

    if (_readChar == null || _writeChar == null) {
      throw StateError('Required BLE characteristics not found');
    }

    _cachedDeviceId = deviceId;
    debugPrint('✅ BLE characteristics cached for device: $deviceId');

    return (readChar: _readChar!, writeChar: _writeChar!);
  }

  /// Gets only the write characteristic (for commands that don't need read).
  Future<BluetoothCharacteristic> getWriteCharacteristic(String deviceId) async {
    final chars = await getCharacteristics(deviceId);
    return chars.writeChar;
  }

  /// Gets only the read characteristic.
  Future<BluetoothCharacteristic> getReadCharacteristic(String deviceId) async {
    final chars = await getCharacteristics(deviceId);
    return chars.readChar;
  }

  /// Clears the cached characteristics (call on disconnect).
  void clearCache() {
    _cachedDeviceId = null;
    _readChar = null;
    _writeChar = null;
    debugPrint('🧹 BLE characteristic cache cleared');
  }

  /// Reads from the read characteristic with automatic retry on failure.
  ///
  /// Retries up to [maxRetries] times with exponential backoff.
  Future<List<int>> readWithRetry(String deviceId, {int maxRetries = 3}) async {
    final readChar = await getReadCharacteristic(deviceId);

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await readChar.read();
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;
        if (isLastAttempt) {
          debugPrint('❌ BLE read failed after ${maxRetries + 1} attempts: $e');
          rethrow;
        }

        // Exponential backoff: 100ms, 200ms, 400ms
        final delay = Duration(milliseconds: 100 * (1 << attempt));
        debugPrint('⚠️ BLE read failed (attempt ${attempt + 1}/${maxRetries + 1}), retrying in ${delay.inMilliseconds}ms: $e');
        await Future.delayed(delay);
      }
    }
    throw StateError('Unreachable');
  }
}
