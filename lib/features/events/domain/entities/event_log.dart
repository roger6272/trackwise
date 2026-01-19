import 'package:equatable/equatable.dart';

/// EventLog entity representing a single event from the ESP32 device.
///
/// Events are generated when physical items are interacted with (button press).
/// Each event records:
/// - The item that was interacted with
/// - The type of event (increment, decrement, switch, etc.)
/// - The increment/decrement value
/// - The resulting count at time of event
///
/// Domain layer entity - pure Dart with no Flutter/Firebase dependencies.
class EventLog extends Equatable {
  /// Unique identifier matching Firestore document ID
  final String id;

  /// Timestamp when the event was created on the ESP32
  final DateTime createdTime;

  /// Reference to the Item that triggered this event
  final String itemId;

  /// Type of event (e.g., 'increment', 'decrement', 'switch', 'reset')
  final String eventName;

  /// Amount changed in this event (positive for increment, negative for decrement)
  final int increment;

  /// The item's count value after this event was applied
  final int currentCount;

  /// The item's reset number at the time of this event.
  /// Used to group events by reset periods for analysis.
  final int resetNumber;

  /// Firebase UID of the user who owns this event
  final String userId;

  const EventLog({
    required this.id,
    required this.createdTime,
    required this.itemId,
    required this.eventName,
    required this.increment,
    required this.currentCount,
    this.resetNumber = 0,
    required this.userId,
  });

  /// Creates a copy of this event log with the given fields replaced.
  EventLog copyWith({
    String? id,
    DateTime? createdTime,
    String? itemId,
    String? eventName,
    int? increment,
    int? currentCount,
    int? resetNumber,
    String? userId,
  }) {
    return EventLog(
      id: id ?? this.id,
      createdTime: createdTime ?? this.createdTime,
      itemId: itemId ?? this.itemId,
      eventName: eventName ?? this.eventName,
      increment: increment ?? this.increment,
      currentCount: currentCount ?? this.currentCount,
      resetNumber: resetNumber ?? this.resetNumber,
      userId: userId ?? this.userId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        createdTime,
        itemId,
        eventName,
        increment,
        currentCount,
        resetNumber,
        userId,
      ];

  @override
  String toString() {
    return 'EventLog(id: $id, createdTime: $createdTime, itemId: $itemId, '
        'eventName: $eventName, increment: $increment, currentCount: $currentCount, '
        'resetNumber: $resetNumber, userId: $userId)';
  }
}
