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

/// Result of sync operation, optionally including the selected item's Firestore ID.
class SyncDeviceDataResult extends Equatable {
  /// The Firestore ID of the selected item (from prefs or switch event).
  /// Null if no selection change or if the deviceItemId couldn't be mapped.
  final String? selectedFirestoreId;

  /// True if device explicitly reported no item selected (selected_id: -1).
  /// Used to clear app's selection state when device has no selection.
  final bool clearSelection;

  const SyncDeviceDataResult({
    this.selectedFirestoreId,
    this.clearSelection = false,
  });

  @override
  List<Object?> get props => [selectedFirestoreId, clearSelection];
}

/// Use case for syncing ESP32 device messages to Firestore.
///
/// Handles message types:
/// - 'prefs': Updates item counts (count, todaycount, lastResetTime)
/// - 'event': Inserts EventLog records for increment/decrement/switch events
/// - 'logs': Inserts historical EventLog records
/// - 'item_delta': Updates a single item's counts
///
/// This bridges the Bluetooth layer with Firestore persistence,
/// ensuring device data is synchronized with the database.
///
/// Returns SyncDeviceDataResult which includes:
/// - selectedFirestoreId: The Firestore ID of the currently selected item
///   (mapped from deviceItemId in the message)
@lazySingleton
class SyncDeviceDataUseCase extends UseCase<SyncDeviceDataResult, SyncDeviceDataParams> {
  final ItemRepository itemRepository;
  final EventLogRepository eventLogRepository;

  /// Cache of deviceItemId -> Firestore ID mapping.
  /// Built from items on first use, refreshed when items change.
  Map<int, String> _deviceItemIdMap = {};

  SyncDeviceDataUseCase(this.itemRepository, this.eventLogRepository);

  /// Builds/updates the deviceItemId to Firestore ID mapping.
  Future<void> _buildMapping(String userId) async {
    final itemsResult = await itemRepository.getItems(userId);
    itemsResult.fold(
      (failure) {
        debugPrint('Failed to build deviceItemId mapping: ${failure.message}');
      },
      (items) {
        _deviceItemIdMap = {
          for (final item in items)
            if (item.deviceItemId != null) item.deviceItemId!: item.id
        };
        debugPrint('Built deviceItemId mapping: ${_deviceItemIdMap.length} items');
      },
    );
  }

  /// Looks up Firestore ID from deviceItemId.
  /// Returns null if not found or if deviceItemId is -1 (no selection).
  String? _getFirestoreId(int? deviceItemId) {
    if (deviceItemId == null || deviceItemId < 0) return null;
    return _deviceItemIdMap[deviceItemId];
  }

  @override
  Future<Either<Failure, SyncDeviceDataResult>> call(SyncDeviceDataParams params) async {
    final message = params.message;
    final userId = params.userId;

    // Build/refresh mapping for messages that need ID translation
    if (message.type == BleMessageType.prefs ||
        message.type == BleMessageType.event ||
        message.type == BleMessageType.logs ||
        message.type == BleMessageType.itemDelta) {
      await _buildMapping(userId);
    }

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
        return const Right(SyncDeviceDataResult());
    }
  }

  /// Syncs prefs message - updates item counts in Firestore.
  ///
  /// Data format (from ble_message_model):
  /// {
  ///   'items': [...],  // List of items with {id (deviceItemId), count, todaycount, lastResetTime}
  ///   'selectedDeviceItemId': int?  // The currently selected item's deviceItemId
  /// }
  Future<Either<Failure, SyncDeviceDataResult>> _syncPrefsMessage(
    BleMessage message,
    String userId,
  ) async {
    final data = message.data;
    if (data == null) return const Right(SyncDeviceDataResult());

    // Extract items and selectedDeviceItemId from wrapped data
    final List<dynamic>? items;
    int? selectedDeviceItemId;

    if (data is Map<String, dynamic>) {
      items = data['items'] as List<dynamic>?;
      selectedDeviceItemId = data['selectedDeviceItemId'] as int?;
    } else if (data is List) {
      // Backward compatibility: data is just the list of items
      items = data;
    } else {
      return const Right(SyncDeviceDataResult());
    }

    if (items == null || items.isEmpty) {
      // No items, but may still have a selected item to report
      // If device explicitly says no selection (-1), signal to clear app's selection
      final selectedFirestoreId = _getFirestoreId(selectedDeviceItemId);
      final clearSelection = selectedDeviceItemId == -1;
      return Right(SyncDeviceDataResult(
        selectedFirestoreId: selectedFirestoreId,
        clearSelection: clearSelection,
      ));
    }

    // Map deviceItemIds to Firestore IDs for batch update
    final List<Map<String, dynamic>> itemData = [];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;

      final deviceItemId = item['id'] as int?;
      final firestoreId = _getFirestoreId(deviceItemId);
      if (firestoreId == null) continue;

      itemData.add({
        'id': firestoreId, // Use Firestore ID for update
        'count': item['count'],
        'todaycount': item['todaycount'],
        'lastResetTime': item['lastResetTime'],
        'resetNumber': item['resetNumber'],
      });
    }

    if (itemData.isNotEmpty) {
      final result = await itemRepository.batchUpdateCounts(userId, itemData);
      if (result.isLeft()) {
        return result.fold(
          (failure) => Left(failure),
          (_) => const Right(SyncDeviceDataResult()),
        );
      }
    }

    // Return the selected Firestore ID for the BLoC to update its state
    // If device explicitly says no selection (-1), signal to clear app's selection
    final selectedFirestoreId = _getFirestoreId(selectedDeviceItemId);
    final clearSelection = selectedDeviceItemId == -1;
    return Right(SyncDeviceDataResult(
      selectedFirestoreId: selectedFirestoreId,
      clearSelection: clearSelection,
    ));
  }

  /// Syncs event message - inserts EventLog records.
  ///
  /// For 'switch' events, returns the selected Firestore ID.
  /// For other events, inserts the event log.
  Future<Either<Failure, SyncDeviceDataResult>> _syncEventMessage(
    BleMessage message,
    String userId,
  ) async {
    final data = message.data;
    if (data == null) return const Right(SyncDeviceDataResult());

    // Convert single event or list of events
    final List<dynamic> eventsList;
    if (data is List) {
      eventsList = data;
    } else if (data is Map) {
      eventsList = [data];
    } else {
      return const Right(SyncDeviceDataResult());
    }

    String? selectedFirestoreId;
    final events = <EventLog>[];

    for (final eventData in eventsList) {
      if (eventData is! Map<String, dynamic>) continue;

      final eventName = eventData['event']?.toString() ?? 'unknown';

      // Get deviceItemId - may be in 'deviceItemId' (new) or 'itemId' (as int)
      final deviceItemId = eventData['deviceItemId'] as int? ??
          (eventData['itemId'] is int ? eventData['itemId'] as int : null);
      final firestoreId = _getFirestoreId(deviceItemId);

      // For switch events, extract the selected item but don't create EventLog
      if (eventName == 'switch') {
        selectedFirestoreId = firestoreId;
        continue;
      }

      if (firestoreId == null) continue;

      // ESP32 sends timestamp in seconds
      final timestampSeconds = eventData['timestamp'] as int? ?? 0;
      final count = eventData['count'] as int? ?? 0;
      final increment = eventData['increment'] as int? ?? 0;
      final resetNumber = eventData['resetNumber'] as int? ?? 0;

      final createdTime = DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000);

      // Generate unique ID including resetNumber to avoid collisions
      final id = '$firestoreId-$eventName-$timestampSeconds-$count-$resetNumber';

      events.add(EventLog(
        id: id,
        createdTime: createdTime,
        itemId: firestoreId, // Use Firestore ID
        eventName: eventName,
        increment: increment,
        currentCount: count,
        resetNumber: resetNumber,
        userId: userId,
      ));
    }

    if (events.isNotEmpty) {
      final result = await eventLogRepository.insertEvents(events);
      if (result.isLeft()) {
        return result.fold(
          (failure) => Left(failure),
          (_) => const Right(SyncDeviceDataResult()),
        );
      }
    }

    return Right(SyncDeviceDataResult(selectedFirestoreId: selectedFirestoreId));
  }

  /// Syncs logs message - inserts historical EventLog records from device.
  ///
  /// Similar to _syncEventMessage but handles the 'logs' format which is
  /// used for bulk historical data from the device's log storage.
  /// itemId in each entry is now a numeric deviceItemId.
  Future<Either<Failure, SyncDeviceDataResult>> _syncLogsMessage(
    BleMessage message,
    String userId,
  ) async {
    final data = message.data;
    if (data == null) return const Right(SyncDeviceDataResult());

    // Data should be a list of log entries
    final List<dynamic> logsList;
    if (data is List) {
      logsList = data;
    } else {
      return const Right(SyncDeviceDataResult());
    }

    final events = <EventLog>[];
    for (final logData in logsList) {
      if (logData is! Map<String, dynamic>) continue;

      final eventName = logData['event']?.toString() ?? 'unknown';

      // Get deviceItemId - now numeric
      final deviceItemId = logData['itemId'] as int?;
      final firestoreId = _getFirestoreId(deviceItemId);
      if (firestoreId == null) continue;

      // Skip switch events - they don't create EventLog entries
      if (eventName == 'switch') continue;

      // ESP32 sends timestamp in seconds
      final timestampSeconds = logData['timestamp'] as int? ?? 0;
      final count = logData['count'] as int? ?? 0;
      final increment = logData['increment'] as int? ?? 0;
      final resetNumber = logData['resetNumber'] as int? ?? 0;

      final createdTime = DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000);

      // Generate unique ID including resetNumber to avoid collisions
      final id = '$firestoreId-$eventName-$timestampSeconds-$count-$resetNumber';

      events.add(EventLog(
        id: id,
        createdTime: createdTime,
        itemId: firestoreId, // Use Firestore ID
        eventName: eventName,
        increment: increment,
        currentCount: count,
        resetNumber: resetNumber,
        userId: userId,
      ));
    }

    if (events.isEmpty) return const Right(SyncDeviceDataResult());

    final result = await eventLogRepository.insertEvents(events);
    return result.fold(
      (failure) => Left(failure),
      (_) => const Right(SyncDeviceDataResult()),
    );
  }

  /// Syncs item delta message - updates a single item's counts in Firestore.
  ///
  /// This is more efficient than prefs for real-time updates (increment/reset)
  /// as it only updates one item instead of all items.
  /// The 'id' field is now a numeric deviceItemId.
  Future<Either<Failure, SyncDeviceDataResult>> _syncItemDeltaMessage(
    BleMessage message,
    String userId,
  ) async {
    final data = message.data;
    if (data == null || data is! Map<String, dynamic>) {
      return const Right(SyncDeviceDataResult());
    }

    // Get deviceItemId - stored as 'deviceItemId' by ble_message_model
    final deviceItemId = data['deviceItemId'] as int?;
    final firestoreId = _getFirestoreId(deviceItemId);
    if (firestoreId == null) return const Right(SyncDeviceDataResult());

    final count = data['count'] as int? ?? 0;
    final todayCount = data['todaycount'] as int? ?? 0;
    final lastResetTimeSeconds = data['lastResetTime'] as int? ?? 0;
    final resetNumber = data['resetNumber'] as int? ?? 0;

    // Use batchUpdateCounts with a single item - it handles the logic
    final result = await itemRepository.batchUpdateCounts(userId, [
      {
        'id': firestoreId, // Use Firestore ID
        'count': count,
        'todaycount': todayCount,
        'lastResetTime': lastResetTimeSeconds,
        'resetNumber': resetNumber,
      }
    ]);

    return result.fold(
      (failure) => Left(failure),
      (_) => const Right(SyncDeviceDataResult()),
    );
  }

  /// Handles error message from firmware - logs the error for debugging.
  ///
  /// Error messages indicate command failures on the device side.
  /// Format: {"type": "error", "cmd": "<command>", "reason": "<reason>"}
  Future<Either<Failure, SyncDeviceDataResult>> _handleErrorMessage(
    BleMessage message,
  ) async {
    final data = message.data;
    if (data == null || data is! Map<String, dynamic>) {
      return const Right(SyncDeviceDataResult());
    }

    final cmd = data['cmd']?.toString() ?? 'unknown';
    final reason = data['reason']?.toString() ?? 'unknown';

    // Log the error for debugging visibility
    debugPrint('BLE Error from device: cmd=$cmd, reason=$reason');

    // Error messages don't require Firestore sync, just logging
    return const Right(SyncDeviceDataResult());
  }
}
