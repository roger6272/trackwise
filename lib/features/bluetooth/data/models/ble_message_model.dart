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
  ///   "selected_id": "item_id"
  /// }
  /// ```
  ///
  /// For 'event' (real-time event):
  /// ```json
  /// {
  ///   "type": "event",
  ///   "data": {
  ///     "event": "increment",
  ///     "itemId": "...",
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
    // Format: {"type": "item_delta", "id": "...", "count": N, "todaycount": N, "lastResetTime": N}
    if (type == BleMessageType.itemDelta) {
      return BleMessageModel(
        type: type,
        data: {
          'id': parsed['id'],
          'count': parsed['count'],
          'todaycount': parsed['todaycount'],
          'lastResetTime': parsed['lastResetTime'],
        },
        receivedAt: DateTime.now(),
      );
    }

    final data = parsed['data'];

    // Extract selectedId based on message type:
    // - For 'prefs': selected_id is at top level
    // - For 'event' with 'switch': itemId is inside data object
    String? selectedId = parsed['selected_id'] as String?;
    if (selectedId == null && type == BleMessageType.event && data is Map<String, dynamic>) {
      if (data['event'] == 'switch') {
        selectedId = data['itemId'] as String?;
      }
    }

    return BleMessageModel(
      type: type,
      data: data,
      selectedId: selectedId,
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
      case BleMessageType.unknown:
        return 'unknown';
    }
  }
}
