import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../custom_code/actions/prepare_b_l_e_read.dart' as old_ble;
import '../../../items/domain/entities/item.dart';
import '../../domain/entities/ble_connection_state.dart';
import '../../domain/entities/ble_device.dart';
import '../../domain/entities/ble_message.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../datasources/bluetooth_datasource.dart';
import '../models/ble_message_model.dart';

/// Implementation of BluetoothRepository using BluetoothDataSource.
///
/// Handles error conversion and data transformation between
/// datasource and domain layers.
@LazySingleton(as: BluetoothRepository)
class BluetoothRepositoryImpl implements BluetoothRepository {
  final BluetoothDataSource dataSource;

  BluetoothRepositoryImpl(this.dataSource);

  @override
  Stream<Either<Failure, List<BleDevice>>> scanDevices({
    Duration timeout = const Duration(seconds: 15),
  }) async* {
    try {
      await for (final devices in dataSource.scanDevices(timeout: timeout)) {
        yield Right(devices.map((m) => m.toEntity()).toList());
      }
    } catch (e) {
      yield Left(BluetoothFailure('Scan failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> stopScan() async {
    try {
      await dataSource.stopScan();
      return const Right(null);
    } catch (e) {
      return Left(BluetoothFailure('Failed to stop scan: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> connect(String deviceId) async {
    try {
      final device = await dataSource.connect(deviceId);
      await dataSource.discoverServices(device);
      // Only emit connected state AFTER services are discovered
      // This ensures characteristics are cached before any listeners react
      dataSource.emitConnectedState();
      return const Right(true);
    } catch (e) {
      return Left(BluetoothFailure( 'Connection failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> disconnect(String deviceId) async {
    try {
      await dataSource.disconnect(deviceId);
      return const Right(null);
    } catch (e) {
      return Left(BluetoothFailure( 'Disconnect failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, BleDevice?>> getConnectedDevice() async {
    try {
      return Right(dataSource.connectedDevice?.toEntity());
    } catch (e) {
      return Left(BluetoothFailure( 'Failed to get connected device: ${e.toString()}'));
    }
  }

  @override
  Stream<Either<Failure, BleConnectionState>> watchConnectionState(
    String deviceId,
  ) {
    // Use map instead of async* to avoid timing issues with broadcast streams
    return dataSource.watchConnectionState(deviceId).map(
      (state) => Right<Failure, BleConnectionState>(state),
    );
  }

  @override
  Future<Either<Failure, void>> sendItems(
    String deviceId,
    List<Item> items,
  ) async {
    try {
      final jsonData = _formatItemsForEsp32(items);
      await dataSource.writeItems(deviceId, jsonData);
      return const Right(null);
    } catch (e) {
      return Left(BluetoothFailure( 'Failed to send items: ${e.toString()}'));
    }
  }

  /// Formats items list for ESP32 consumption.
  ///
  /// Converts domain Item entities to JSON format expected by ESP32:
  /// ```json
  /// [
  ///   {
  ///     "id": "item_id",
  ///     "name": "Item Name",
  ///     "count": 100,
  ///     "todaycount": 10,
  ///     "increment": 1,
  ///     "reminder": 0,
  ///     "reminder_value": 0,
  ///     "lastResetTime": 1234567890
  ///   }
  /// ]
  /// ```
  String _formatItemsForEsp32(List<Item> items) {
    final itemList = items.map((item) => {
      'id': item.id,
      'name': item.name,
      'count': item.count,
      'todaycount': item.todayCount,
      'increment': item.incrementBy,
      'reminder': _reminderTypeToInt(item.reminder),
      'reminder_value': item.reminderValue,
      'lastResetTime': item.lastResetTime.toUtc().millisecondsSinceEpoch ~/ 1000,
    }).toList();

    return jsonEncode(itemList);
  }

  /// Converts ReminderType enum to ESP32 integer format.
  int _reminderTypeToInt(ReminderType type) {
    switch (type) {
      case ReminderType.none:
        return 0;
      case ReminderType.target:
        return 1;
      case ReminderType.interval:
        return 2;
      case ReminderType.everyTime:
        return 2; // Same as interval for ESP32
    }
  }

  @override
  Future<Either<Failure, void>> sendSelectedItem(
    String deviceId,
    String itemId,
  ) async {
    try {
      // Format must match FlutterFlow's send_selected_item_to_device.dart:
      // {"cmd": "set_selected", "id": selectedId}
      final jsonData = jsonEncode({
        'cmd': 'set_selected',
        'id': itemId,
      });
      await dataSource.writeCommand(deviceId, jsonData);
      return const Right(null);
    } catch (e) {
      return Left(BluetoothFailure( 'Failed to send selected item: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> sendTimeSync(String deviceId) async {
    try {
      final now = DateTime.now();
      final jsonData = jsonEncode({
        'type': 'time',
        'timestamp': now.toUtc().millisecondsSinceEpoch ~/ 1000,
        'timezone': now.timeZoneOffset.inHours,
      });
      await dataSource.writeCommand(deviceId, jsonData);
      return const Right(null);
    } catch (e) {
      return Left(BluetoothFailure( 'Failed to send time sync: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> requestData(
    String deviceId,
    String type,
    int page,
  ) async {
    try {
      // Use the OLD working code directly since it works and our new code doesn't
      // The old code handles everything: discover services, write command, read response
      await old_ble.prepareBLERead(deviceId, type, page);
      return const Right(null);
    } catch (e) {
      return Left(BluetoothFailure('Failed to request data: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> clearLogs(String deviceId) async {
    try {
      final jsonData = jsonEncode({
        'type': 'clear_logs',
      });
      await dataSource.writeCommand(deviceId, jsonData);
      return const Right(null);
    } catch (e) {
      return Left(BluetoothFailure( 'Failed to clear logs: ${e.toString()}'));
    }
  }

  @override
  Stream<Either<Failure, BleMessage>> watchMessages(String deviceId) async* {
    try {
      await for (final message in dataSource.watchNotifications(deviceId)) {
        yield Right(message);
      }
    } catch (e) {
      yield Left(BluetoothFailure( 'Message stream error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, BleMessage>> readData(String deviceId) async {
    try {
      final data = await dataSource.readData(deviceId);
      final message = BleMessageModel.fromJson(data);
      return Right(message);
    } catch (e) {
      return Left(BluetoothFailure( 'Failed to read data: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isBluetoothEnabled() async {
    try {
      final enabled = await dataSource.isBluetoothEnabled();
      return Right(enabled);
    } catch (e) {
      return Left(BluetoothFailure( 'Failed to check Bluetooth state: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> requestPermissions() async {
    try {
      final granted = await dataSource.requestPermissions();
      return Right(granted);
    } catch (e) {
      return Left(BluetoothFailure( 'Failed to request permissions: ${e.toString()}'));
    }
  }
}
