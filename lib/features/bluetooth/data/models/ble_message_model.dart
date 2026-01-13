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

    return BleMessageModel(
      type: _parseType(typeStr),
      data: parsed['data'],
      selectedId: parsed['selected_id'] as String?,
      hasMore: parsed['hasMore'] == true,
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
      case BleMessageType.unknown:
        return 'unknown';
    }
  }
}
