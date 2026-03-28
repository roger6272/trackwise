import 'dart:convert';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import '../../../../core/utils/logger.dart';
import '../../../bluetooth/data/datasources/bluetooth_datasource.dart';
import '../../../bluetooth/data/datasources/device_connection.dart';
import '../../../bluetooth/domain/entities/ble_message.dart';
import 'ota_ble_datasource.dart';

/// Implementation of [OtaBleDatasource] using existing Bluetooth infrastructure.
///
/// Sends OTA control commands via the existing command characteristic
/// and firmware binary data via the dedicated OTA Data characteristic.
@LazySingleton(as: OtaBleDatasource)
class OtaBleDatasourceImpl implements OtaBleDatasource {
  final BluetoothDataSource _bluetoothDataSource;

  OtaBleDatasourceImpl(this._bluetoothDataSource);

  /// Gets the active DeviceConnection, throwing if not connected.
  DeviceConnection get _connection {
    final device = _bluetoothDataSource.connectedDevice;
    if (device == null) {
      throw StateError('No device connected for OTA');
    }
    final conn = _bluetoothDataSource.getConnection(device.id);
    if (conn == null) {
      throw StateError('No active connection for OTA');
    }
    return conn;
  }

  /// Gets the device ID of the currently connected device.
  String get _deviceId {
    final device = _bluetoothDataSource.connectedDevice;
    if (device == null) {
      throw StateError('No device connected for OTA');
    }
    return device.id;
  }

  @override
  Future<void> sendOtaStart({
    required int expectedSize,
    required String expectedHash,
    required String version,
  }) async {
    AppLogger.debug(
        'Sending ota_start: size=$expectedSize, hash=${expectedHash.substring(0, 8)}..., version=$version');

    final command = jsonEncode({
      'cmd': 'ota_start',
      'size': expectedSize,
      'sha256': expectedHash,
      'version': version,
    });

    await _bluetoothDataSource.writeCommand(_deviceId, command);
  }

  @override
  Future<void> sendOtaEnd() async {
    AppLogger.debug('Sending ota_end');

    final command = jsonEncode({'cmd': 'ota_end'});
    await _bluetoothDataSource.writeCommand(_deviceId, command);
  }

  @override
  Future<void> sendReboot() async {
    AppLogger.debug('Sending reboot');

    final command = jsonEncode({'cmd': 'reboot'});
    await _bluetoothDataSource.writeCommand(_deviceId, command);
  }

  @override
  Future<void> writeOtaChunk(Uint8List chunk) async {
    final conn = _connection;
    final otaChar = conn.otaDataChar;

    if (otaChar == null) {
      throw StateError(
          'OTA Data characteristic not available — firmware may not support OTA');
    }

    // Write with response for reliability
    await otaChar.write(chunk, withoutResponse: false);
  }

  @override
  Stream<Map<String, dynamic>> listenForOtaNotifications() {
    final deviceId = _deviceId;

    // Filter the existing notification stream for OTA-related messages
    return _bluetoothDataSource.watchNotifications(deviceId).where((message) {
      // OTA responses come as syncResponse type (they have a "status" field)
      return message.type == BleMessageType.syncResponse ||
          message.type == BleMessageType.error;
    }).map((message) {
      final data = message.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      return <String, dynamic>{};
    });
  }
}
