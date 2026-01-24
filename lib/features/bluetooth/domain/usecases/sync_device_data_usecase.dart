import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../events/domain/entities/event_log.dart';
import '../../../events/domain/repositories/event_log_repository.dart';
import '../../../items/domain/repositories/item_repository.dart';
import '../entities/ble_message.dart';

/// Parameters for SyncDeviceDataUseCase.
class SyncDeviceDataParams extends Equatable {
  final BleMessage message;
  final String userId;

  const SyncDeviceDataParams({
    required this.message,
    required this.userId,
  });

  @override
  List<Object> get props => [message, userId];
}

/// Use case for syncing ESP32 device messages to Firestore.
///
/// Handles two message types:
/// - 'prefs': Updates item counts (count, todaycount, lastResetTime)
/// - 'event': Inserts EventLog records for increment/decrement/switch events
///
/// This bridges the Bluetooth layer with Firestore persistence,
/// ensuring device data is synchronized with the database.
@lazySingleton
class SyncDeviceDataUseCase extends UseCase<void, SyncDeviceDataParams> {
  final ItemRepository itemRepository;
  final EventLogRepository eventLogRepository;

  SyncDeviceDataUseCase(this.itemRepository, this.eventLogRepository);

  @override
  Future<Either<Failure, void>> call(SyncDeviceDataParams params) async {
    final message = params.message;
    final userId = params.userId;

    switch (message.type) {
      case BleMessageType.prefs:
        return _syncPrefsMessage(message, userId);
      case BleMessageType.event:
        return _syncEventMessage(message, userId);
      case BleMessageType.logs:
        return _syncLogsMessage(message, userId);
      case BleMessageType.itemDelta:
        return _syncItemDeltaMessage(message, userId);
      case BleMessageType.error:
        return _handleErrorMessage(message);
      case BleMessageType.unknown:
        return const Right(null);
    }
  }

  /// Syncs prefs message - updates item counts in Firestore.
  Future<Either<Failure, void>> _syncPrefsMessage(
    BleMessage message,
    String userId,
  ) async {
    final data = message.data;
    if (data == null) return const Right(null);

    // Data should be a list of items with {id, count, todaycount, lastResetTime}
    final List<Map<String, dynamic>> itemData;
    if (data is List) {
      itemData = data.cast<Map<String, dynamic>>();
    } else {
      return const Right(null);
    }

    return await itemRepository.batchUpdateCounts(userId, itemData);
  }

  /// Syncs event message - inserts EventLog records.
  Future<Either<Failure, void>> _syncEventMessage(
    BleMessage message,
    String userId,
  ) async {
    final data = message.data;
    if (data == null) return const Right(null);

    // Convert single event or list of events
    final List<dynamic> eventsList;
    if (data is List) {
      eventsList = data;
    } else if (data is Map) {
      eventsList = [data];
    } else {
      return const Right(null);
    }

    final events = <EventLog>[];
    for (final eventData in eventsList) {
      if (eventData is! Map<String, dynamic>) continue;

      final eventName = eventData['event']?.toString() ?? 'unknown';
      final itemId = eventData['itemId']?.toString();
      if (itemId == null) continue;

      // Skip switch events - they don't create EventLog entries
      // (handled by the InsertEventsUseCase, but we filter here too)
      if (eventName == 'switch') continue;

      // ESP32 sends timestamp in seconds
      final timestampSeconds = eventData['timestamp'] as int? ?? 0;
      final count = eventData['count'] as int? ?? 0;
      final increment = eventData['increment'] as int? ?? 0;
      final resetNumber = eventData['resetNumber'] as int? ?? 0;

      final createdTime = DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000);

      // Generate unique ID including resetNumber to avoid collisions
      final id = '$itemId-$eventName-$timestampSeconds-$count-$resetNumber';

      events.add(EventLog(
        id: id,
        createdTime: createdTime,
        itemId: itemId,
        eventName: eventName,
        increment: increment,
        currentCount: count,
        resetNumber: resetNumber,
        userId: userId,
      ));
    }

    if (events.isEmpty) return const Right(null);

    return await eventLogRepository.insertEvents(events);
  }

  /// Syncs logs message - inserts historical EventLog records from device.
  ///
  /// Similar to _syncEventMessage but handles the 'logs' format which is
  /// used for bulk historical data from the device's log storage.
  Future<Either<Failure, void>> _syncLogsMessage(
    BleMessage message,
    String userId,
  ) async {
    final data = message.data;
    if (data == null) return const Right(null);

    // Data should be a list of log entries
    final List<dynamic> logsList;
    if (data is List) {
      logsList = data;
    } else {
      return const Right(null);
    }

    final events = <EventLog>[];
    for (final logData in logsList) {
      if (logData is! Map<String, dynamic>) continue;

      final eventName = logData['event']?.toString() ?? 'unknown';
      final itemId = logData['itemId']?.toString();
      if (itemId == null) continue;

      // Skip switch events - they don't create EventLog entries
      if (eventName == 'switch') continue;

      // ESP32 sends timestamp in seconds
      final timestampSeconds = logData['timestamp'] as int? ?? 0;
      final count = logData['count'] as int? ?? 0;
      final increment = logData['increment'] as int? ?? 0;
      final resetNumber = logData['resetNumber'] as int? ?? 0;

      final createdTime = DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000);

      // Generate unique ID including resetNumber to avoid collisions
      final id = '$itemId-$eventName-$timestampSeconds-$count-$resetNumber';

      events.add(EventLog(
        id: id,
        createdTime: createdTime,
        itemId: itemId,
        eventName: eventName,
        increment: increment,
        currentCount: count,
        resetNumber: resetNumber,
        userId: userId,
      ));
    }

    if (events.isEmpty) return const Right(null);

    return await eventLogRepository.insertEvents(events);
  }

  /// Syncs item delta message - updates a single item's counts in Firestore.
  ///
  /// This is more efficient than prefs for real-time updates (increment/reset)
  /// as it only updates one item instead of all items.
  Future<Either<Failure, void>> _syncItemDeltaMessage(
    BleMessage message,
    String userId,
  ) async {
    final data = message.data;
    if (data == null || data is! Map<String, dynamic>) return const Right(null);

    final itemId = data['id']?.toString();
    if (itemId == null) return const Right(null);

    final count = data['count'] as int? ?? 0;
    final todayCount = data['todaycount'] as int? ?? 0;
    final lastResetTimeSeconds = data['lastResetTime'] as int? ?? 0;
    final resetNumber = data['resetNumber'] as int? ?? 0;

    // Use batchUpdateCounts with a single item - it handles the logic
    return await itemRepository.batchUpdateCounts(userId, [
      {
        'id': itemId,
        'count': count,
        'todaycount': todayCount,
        'lastResetTime': lastResetTimeSeconds,
        'resetNumber': resetNumber,
      }
    ]);
  }

  /// Handles error message from firmware - logs the error for debugging.
  ///
  /// Error messages indicate command failures on the device side.
  /// Format: {"type": "error", "cmd": "<command>", "reason": "<reason>"}
  Future<Either<Failure, void>> _handleErrorMessage(BleMessage message) async {
    final data = message.data;
    if (data == null || data is! Map<String, dynamic>) return const Right(null);

    final cmd = data['cmd']?.toString() ?? 'unknown';
    final reason = data['reason']?.toString() ?? 'unknown';

    // Log the error for debugging visibility
    debugPrint('BLE Error from device: cmd=$cmd, reason=$reason');

    // Error messages don't require Firestore sync, just logging
    return const Right(null);
  }
}
