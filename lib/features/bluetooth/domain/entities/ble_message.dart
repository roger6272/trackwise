import 'package:equatable/equatable.dart';

/// Types of messages received from ESP32 device.
///
/// Each type corresponds to a different data structure:
/// - [prefs]: Item status updates with counts and selected item
/// - [event]: Real-time events (increment, switch, etc.)
/// - [logs]: Historical event logs with pagination
/// - [unknown]: Unrecognized message type
enum BleMessageType {
  /// Item preferences/status update
  /// Contains: data (list of items), selected_id
  prefs,

  /// Real-time event notification
  /// Contains: data with event, itemId, timestamp, count, increment
  event,

  /// Historical log data (paginated)
  /// Contains: data (list of events), hasMore flag
  logs,

  /// Unknown or malformed message
  unknown,
}

/// Represents a message received from the ESP32 device.
///
/// Messages are JSON-formatted and received via BLE notifications.
/// The [type] field determines how [data] should be interpreted.
///
/// Domain layer entity - pure Dart with no external dependencies.
class BleMessage extends Equatable {
  /// Message type determining data structure
  final BleMessageType type;

  /// Raw message data as parsed JSON
  /// Structure depends on [type]
  final dynamic data;

  /// Currently selected item ID (for prefs messages)
  final String? selectedId;

  /// Whether more data is available (for paginated logs)
  final bool hasMore;

  /// When the message was received
  final DateTime receivedAt;

  const BleMessage({
    required this.type,
    required this.data,
    this.selectedId,
    this.hasMore = false,
    required this.receivedAt,
  });

  /// Creates a copy with the given fields replaced.
  BleMessage copyWith({
    BleMessageType? type,
    dynamic data,
    String? selectedId,
    bool? hasMore,
    DateTime? receivedAt,
  }) {
    return BleMessage(
      type: type ?? this.type,
      data: data ?? this.data,
      selectedId: selectedId ?? this.selectedId,
      hasMore: hasMore ?? this.hasMore,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  @override
  List<Object?> get props => [type, data, selectedId, hasMore, receivedAt];

  @override
  String toString() {
    return 'BleMessage(type: $type, selectedId: $selectedId, hasMore: $hasMore, receivedAt: $receivedAt)';
  }
}
