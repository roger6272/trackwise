import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../items/domain/entities/item.dart';
import '../../domain/entities/ble_connection_state.dart';
import '../../domain/entities/ble_device.dart';
import '../../domain/entities/ble_message.dart';
import '../../domain/entities/sync_state.dart';
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
    List<Item> items, {
    Map<String, String> categoryNames = const {},
  }) async {
    try {
      final jsonData = _formatItemsForEsp32(items, categoryNames);
      if (kDebugMode) print('JSON sent to device: $jsonData');
      await dataSource.writeItems(deviceId, jsonData);
      return const Right(null);
    } catch (e) {
      return Left(BluetoothFailure( 'Failed to send items: ${e.toString()}'));
    }
  }

  /// Formats items list for ESP32 consumption.
  ///
  /// Converts domain Item entities to JSON format expected by ESP32.
  /// Uses deviceItemId (0-99) instead of Firestore ID to reduce memory.
  /// Count and todaycount are sent for new/restored items - device preserves
  /// its own counts for existing items but uses these values for new items.
  /// ```json
  /// [
  ///   {
  ///     "id": 0,  // deviceItemId (0-99) instead of Firestore string ID
  ///     "name": "Item Name",
  ///     "increment": 1,
  ///     "reminder": 0,
  ///     "reminder_value": 0,
  ///     "lastResetTime": 1234567890,
  ///     "count": 10,
  ///     "todaycount": 5,
  ///     "reset_number": 0,
  ///     "category": "Category Name"
  ///   }
  /// ]
  /// ```
  String _formatItemsForEsp32(
    List<Item> items,
    Map<String, String> categoryNames,
  ) {
    final itemList = items.map((item) => {
      'id': item.deviceItemId ?? 0, // Use numeric deviceItemId for BLE
      'name': item.name,
      'increment': item.incrementBy,
      'reminder': _reminderTypeToInt(item.reminder),
      'reminder_value': item.reminderValue,
      'lastResetTime': (item.lastResetTime?.toUtc().millisecondsSinceEpoch ?? 0) ~/ 1000,
      'count': item.count,
      'todaycount': item.todayCount,
      'reset_number': item.resetNumber,
      'category': (item.categoryId == null || item.categoryId!.isEmpty)
          ? 'Uncategorized'
          : (categoryNames[item.categoryId] ?? 'Uncategorized'),
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
    }
  }

  @override
  Future<Either<Failure, void>> sendSelectedItem(
    String deviceId,
    int deviceItemId,
  ) async {
    try {
      // Send deviceItemId (0-99) instead of Firestore string ID
      // to reduce ESP32 memory usage
      final jsonData = jsonEncode({
        'cmd': 'set_selected',
        'id': deviceItemId,
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
      // Format: "yyyy-MM-dd HH:mm:ss" as expected by ESP32 firmware
      final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now.toUtc());
      final jsonData = jsonEncode({
        'cmd': 'set_time',
        'utc_time': formattedTime,
        'offset': now.timeZoneOffset.inMinutes,
      });
      await dataSource.writeCommand(deviceId, jsonData);
      return const Right(null);
    } catch (e) {
      return Left(BluetoothFailure('Failed to send time sync: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> requestData(
    String deviceId,
    String type,
    int page,
  ) async {
    try {
      // Build the prepare_read command
      final command = jsonEncode({
        'cmd': 'prepare_read',
        'type': type,
        'page': page,
      });

      debugPrint('📤 Sending prepare_read: type=$type, page=$page');

      // Just send the command - response will arrive via notification
      // through the existing message stream (handled by BLoC's MessageReceived)
      await dataSource.writeCommand(deviceId, command);

      return const Right(null);
    } catch (e) {
      debugPrint('❌ requestData failed: $e');
      return Left(BluetoothFailure('Failed to request data: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> clearLogs(String deviceId) async {
    try {
      final jsonData = jsonEncode({
        'cmd': 'clear_logs',
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

  // ============================================================
  // MULTI-DEVICE SYNC COMMANDS
  // ============================================================

  @override
  Future<Either<Failure, HandshakeResult>> sendHandshake({
    required String uid,
    required int syncSeq,
  }) async {
    try {
      final result = await dataSource.sendHandshake(
        uid: uid,
        syncSeq: syncSeq,
      );
      return Right(result);
    } catch (e) {
      debugPrint('Handshake failed: $e');
      return Left(BluetoothFailure('Handshake failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, OverrideResult>> sendOverrideChunked({
    required String uid,
    required int syncSeq,
    required int selectedId,
    required List<Item> items,
    Map<String, String> categoryNames = const {},
  }) async {
    try {
      final result = await dataSource.sendOverrideChunked(
        uid: uid,
        syncSeq: syncSeq,
        selectedId: selectedId,
        items: items,
        categoryNames: categoryNames,
      );
      return Right(result);
    } catch (e) {
      debugPrint('Override failed: $e');
      return Left(BluetoothFailure('Override failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, SyncCompleteResult>> sendSyncComplete(int syncSeq) async {
    try {
      final result = await dataSource.sendSyncComplete(syncSeq);
      return Right(result);
    } catch (e) {
      debugPrint('sync_complete failed: $e');
      return Left(BluetoothFailure('sync_complete failed: ${e.toString()}'));
    }
  }
}
