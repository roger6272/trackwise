import 'dart:convert';

import '../../domain/entities/ble_message.dart';

/// Data model for BleMessage entity with JSON parsing.
///
/// Extends the domain BleMessage entity and adds factory methods for
/// parsing JSON messages received from the ESP32 device.
class BleMessageModel extends BleMessage {
  const BleMessageModel({
    required super.type,
    required super.data,
    super.selectedId,
    super.hasMore,
    super.page,
    required super.receivedAt,
  });

  /// Creates a BleMessageModel by parsing a JSON string.
  ///
  /// Expected JSON format depends on message type:
  ///
  /// For 'prefs' (item status):
  /// ```json
  /// {
  ///   "type": "prefs",
  ///   "data": [...],
  ///   "selected_id": 0  // deviceItemId (0-99), -1 for none
  /// }
  /// ```
  ///
  /// For 'event' (real-time event):
  /// ```json
  /// {
  ///   "type": "event",
  ///   "data": {
  ///     "event": "increment",
  ///     "itemId": 0,  // deviceItemId (0-99)
  ///     "itemName": "...",
  ///     "timestamp": 1234567890,
  ///     "count": 100,
  ///     "increment": 1
  ///   }
  /// }
  /// ```
  ///
  /// For 'logs' (historical events):
  /// ```json
  /// {
  ///   "type": "logs",
  ///   "data": [...],
  ///   "hasMore": true
  /// }
  /// ```
  ///
  /// Note: IDs are now numeric deviceItemIds (0-99) for memory optimization.
  /// The sync usecase maps these to Firestore IDs.
  ///
  /// Throws [FormatException] if JSON is invalid.
  factory BleMessageModel.fromJson(String jsonString) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw FormatException('Invalid JSON: $e');
    }

    // Handle empty array response (ESP32 returns [] when no data)
    if (decoded is List) {
      return BleMessageModel(
        type: BleMessageType.prefs,
        data: decoded,
        selectedId: null,
        hasMore: false,
        receivedAt: DateTime.now(),
      );
    }

    final parsed = decoded as Map<String, dynamic>;
    final typeStr = parsed['type'] as String?;
    final type = _parseType(typeStr);

    // For item_delta, all fields are at top level (not in 'data')
    // Format: {"type": "item_delta", "id": 0, "count": N, "todaycount": N, "lastResetTime": N, "resetNumber": N}
    // Note: id is now numeric deviceItemId (0-99)
    if (type == BleMessageType.itemDelta) {
      return BleMessageModel(
        type: type,
        data: {
          'deviceItemId': parsed['id'] as int?, // Store as deviceItemId
          'count': parsed['count'],
          'todaycount': parsed['todaycount'],
          'lastResetTime': parsed['lastResetTime'],
          'resetNumber': parsed['resetNumber'],
        },
        receivedAt: DateTime.now(),
      );
    }

    // For error, all fields are at top level (not in 'data')
    // Format: {"type": "error", "cmd": "...", "reason": "..."}
    if (type == BleMessageType.error) {
      return BleMessageModel(
        type: type,
        data: {
          'cmd': parsed['cmd'],
          'reason': parsed['reason'],
        },
        receivedAt: DateTime.now(),
      );
    }

    dynamic data = parsed['data'];

    // Extract selectedDeviceItemId based on message type:
    // - For 'prefs': selected_id is at top level (now numeric, -1 for none)
    // - For 'event' with 'switch': itemId is inside data object (now numeric)
    // Note: selectedId in BleMessage is kept for backward compatibility but
    // the sync usecase uses selectedDeviceItemId to look up the Firestore ID.
    int? selectedDeviceItemId;

    // For prefs, extract the selected_id (now numeric)
    if (type == BleMessageType.prefs) {
      final rawSelectedId = parsed['selected_id'];
      if (rawSelectedId is int) {
        selectedDeviceItemId = rawSelectedId;
      }
      // Wrap data with selectedDeviceItemId for sync usecase
      data = {
        'items': data,
        'selectedDeviceItemId': selectedDeviceItemId,
      };
    }

    // For event with 'switch': itemId is inside data object (now numeric)
    if (type == BleMessageType.event && data is Map<String, dynamic>) {
      if (data['event'] == 'switch') {
        final rawItemId = data['itemId'];
        if (rawItemId is int) {
          selectedDeviceItemId = rawItemId;
        }
      }
      // For all events, itemId is now numeric deviceItemId
      // Store as deviceItemId for clarity
      final rawItemId = data['itemId'];
      if (rawItemId is int) {
        data = Map<String, dynamic>.from(data);
        data['deviceItemId'] = rawItemId;
      }
    }

    // For logs, itemId in each entry is now numeric deviceItemId
    // The sync usecase will handle mapping when processing

    return BleMessageModel(
      type: type,
      data: data,
      selectedId: null, // No longer used, sync usecase handles mapping
      hasMore: parsed['hasMore'] == true,
      page: parsed['page'] as int?,
      receivedAt: DateTime.now(),
    );
  }

  /// Creates a BleMessageModel from a pre-parsed map.
  ///
  /// Used when JSON has already been decoded.
  factory BleMessageModel.fromMap(Map<String, dynamic> map) {
    return BleMessageModel(
      type: _parseType(map['type'] as String?),
      data: map['data'],
      selectedId: map['selected_id'] as String?,
      hasMore: map['hasMore'] == true,
      page: map['page'] as int?,
      receivedAt: DateTime.now(),
    );
  }

  /// Parses message type string to enum.
  static BleMessageType _parseType(String? type) {
    switch (type?.toLowerCase()) {
      case 'prefs':
        return BleMessageType.prefs;
      case 'event':
        return BleMessageType.event;
      case 'logs':
        return BleMessageType.logs;
      case 'item_delta':
        return BleMessageType.itemDelta;
      case 'error':
        return BleMessageType.error;
      default:
        return BleMessageType.unknown;
    }
  }

  /// Converts this model to a domain entity.
  BleMessage toEntity() => this;

  /// Serializes this message to JSON string.
  ///
  /// Useful for logging or caching.
  String toJsonString() {
    return jsonEncode({
      'type': _typeToString(type),
      'data': data,
      if (selectedId != null) 'selected_id': selectedId,
      if (hasMore) 'hasMore': hasMore,
    });
  }

  static String _typeToString(BleMessageType type) {
    switch (type) {
      case BleMessageType.prefs:
        return 'prefs';
      case BleMessageType.event:
        return 'event';
      case BleMessageType.logs:
        return 'logs';
      case BleMessageType.itemDelta:
        return 'item_delta';
      case BleMessageType.error:
        return 'error';
      case BleMessageType.unknown:
        return 'unknown';
    }
  }
}
