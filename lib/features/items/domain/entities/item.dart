import 'package:equatable/equatable.dart';

/// Reminder types for items.
///
/// - [none]: No reminders
/// - [target]: Remind when count reaches reminderValue
/// - [interval]: Remind every reminderValue increments
/// - [everyTime]: Remind on every increment
enum ReminderType {
  none,
  target,
  interval,
  everyTime,
}

/// Item entity representing a tracked physical item.
///
/// Items are tracked using an ESP32 Bluetooth device. Each item has:
/// - Cumulative count (persists across days)
/// - Daily count (resets at midnight on ESP32)
/// - Increment value (amount added per button press)
/// - Reminder settings
///
/// Domain layer entity - pure Dart with no Flutter/Firebase dependencies.
class Item extends Equatable {
  /// Unique identifier matching Firestore document ID
  final String id;

  /// User-defined item name (max 30 characters)
  final String name;

  /// Total cumulative count since item creation
  final int count;

  /// Daily count - resets at midnight on ESP32 device
  final int todayCount;

  /// Amount to increment per event (1-100)
  final int incrementBy;

  /// Type of reminder system
  final ReminderType reminder;

  /// Threshold value for reminders (0-1000)
  ///
  /// - For [ReminderType.target]: Remind when count reaches this value
  /// - For [ReminderType.interval]: Remind every N increments
  /// - For [ReminderType.everyTime]: Value ignored
  /// - For [ReminderType.none]: Value ignored
  final int reminderValue;

  /// Timestamp of last daily reset (performed by ESP32 at midnight)
  final DateTime lastResetTime;

  /// Timestamp of last modification (any update to item)
  final DateTime lastUpdated;

  /// Firebase UID of the item owner
  final String userId;

  const Item({
    required this.id,
    required this.name,
    required this.count,
    required this.todayCount,
    required this.incrementBy,
    required this.reminder,
    required this.reminderValue,
    required this.lastResetTime,
    required this.lastUpdated,
    required this.userId,
  });

  /// Creates a copy of this item with the given fields replaced.
  ///
  /// Used by BLoC for state management and updates.
  Item copyWith({
    String? id,
    String? name,
    int? count,
    int? todayCount,
    int? incrementBy,
    ReminderType? reminder,
    int? reminderValue,
    DateTime? lastResetTime,
    DateTime? lastUpdated,
    String? userId,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
      todayCount: todayCount ?? this.todayCount,
      incrementBy: incrementBy ?? this.incrementBy,
      reminder: reminder ?? this.reminder,
      reminderValue: reminderValue ?? this.reminderValue,
      lastResetTime: lastResetTime ?? this.lastResetTime,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      userId: userId ?? this.userId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        count,
        todayCount,
        incrementBy,
        reminder,
        reminderValue,
        lastResetTime,
        lastUpdated,
        userId,
      ];

  @override
  String toString() {
    return 'Item(id: $id, name: $name, count: $count, todayCount: $todayCount, '
        'incrementBy: $incrementBy, reminder: $reminder, reminderValue: $reminderValue, '
        'lastResetTime: $lastResetTime, lastUpdated: $lastUpdated, userId: $userId)';
  }
}
