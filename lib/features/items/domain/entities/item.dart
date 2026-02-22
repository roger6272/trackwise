import 'package:equatable/equatable.dart';

/// Reminder types for items.
///
/// - [none]: No reminders
/// - [target]: Remind when count reaches reminderValue
/// - [interval]: Remind every reminderValue increments
enum ReminderType {
  none,
  target,
  interval,
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

  /// Amount to increment per event (1-1000)
  final int incrementBy;

  /// Type of reminder system
  final ReminderType reminder;

  /// Threshold value for reminders (0-9999)
  ///
  /// - For [ReminderType.target]: Remind when count reaches this value
  /// - For [ReminderType.interval]: Remind every N increments
  /// - For [ReminderType.none]: Value ignored
  final int reminderValue;

  /// Timestamp of last daily reset (performed by ESP32 at midnight).
  /// Null if the item has never been reset.
  final DateTime? lastResetTime;

  /// Number of times this item has been reset.
  /// Increments each time the reset button is pressed on the device.
  /// Used to track counts between reset periods.
  final int resetNumber;

  /// Timestamp of last modification (any update to item)
  final DateTime lastUpdated;

  /// Firebase UID of the item owner
  final String userId;

  /// Timestamp when item was soft-deleted, null if active.
  /// Items with non-null deletedAt are hidden from normal queries
  /// and permanently deleted after 30 days.
  final DateTime? deletedAt;

  /// Display order for sorting items in the list (0-indexed).
  /// Used for drag-to-reorder functionality.
  final int order;

  /// Initial count when the item was first created.
  /// Used to track starting point for progress calculations.
  final int initialCount;

  /// Target goal count for this item.
  /// When set, enables progress tracking from initialCount to goal.
  /// Null means no goal is set.
  final int? goal;

  /// Category ID this item belongs to.
  /// Null means the item is uncategorized.
  final String? categoryId;

  /// Display order within the item's category (0-indexed).
  /// Used for ordering items when viewing a specific category.
  final int categoryOrder;

  /// Device-side item identifier (0-99).
  /// Used for BLE communication to reduce memory on ESP32.
  /// Assigned on item creation, never changes (except on restore).
  final int? deviceItemId;

  /// User-defined names for reset cycles.
  /// Maps resetNumber (as string) to a custom name.
  /// Empty map means all cycles use generated labels.
  final Map<String, String> cycleNames;

  /// User-defined notes for reset cycles.
  /// Maps resetNumber (as string) to note text (max 250 chars).
  /// Empty map means no notes on any cycle.
  final Map<String, String> cycleNotes;

  const Item({
    required this.id,
    required this.name,
    required this.count,
    required this.todayCount,
    required this.incrementBy,
    required this.reminder,
    required this.reminderValue,
    this.lastResetTime,
    this.resetNumber = 0,
    required this.lastUpdated,
    required this.userId,
    this.deletedAt,
    this.order = 0,
    this.initialCount = 0,
    this.goal,
    this.categoryId,
    this.categoryOrder = 0,
    this.deviceItemId,
    this.cycleNames = const {},
    this.cycleNotes = const {},
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
    int? resetNumber,
    DateTime? lastUpdated,
    String? userId,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? order,
    int? initialCount,
    int? goal,
    bool clearGoal = false,
    String? categoryId,
    bool clearCategoryId = false,
    int? categoryOrder,
    int? deviceItemId,
    Map<String, String>? cycleNames,
    Map<String, String>? cycleNotes,
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
      resetNumber: resetNumber ?? this.resetNumber,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      userId: userId ?? this.userId,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      order: order ?? this.order,
      initialCount: initialCount ?? this.initialCount,
      goal: clearGoal ? null : (goal ?? this.goal),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      categoryOrder: categoryOrder ?? this.categoryOrder,
      deviceItemId: deviceItemId ?? this.deviceItemId,
      cycleNames: cycleNames ?? this.cycleNames,
      cycleNotes: cycleNotes ?? this.cycleNotes,
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
        resetNumber,
        lastUpdated,
        userId,
        deletedAt,
        order,
        initialCount,
        goal,
        categoryId,
        categoryOrder,
        deviceItemId,
        cycleNames,
        cycleNotes,
      ];

  @override
  String toString() {
    return 'Item(id: $id, name: $name, count: $count, todayCount: $todayCount, '
        'incrementBy: $incrementBy, reminder: $reminder, reminderValue: $reminderValue, '
        'lastResetTime: $lastResetTime, resetNumber: $resetNumber, lastUpdated: $lastUpdated, '
        'userId: $userId, deletedAt: $deletedAt, order: $order, initialCount: $initialCount, '
        'goal: $goal, categoryId: $categoryId, categoryOrder: $categoryOrder, '
        'deviceItemId: $deviceItemId, cycleNames: $cycleNames, cycleNotes: $cycleNotes)';
  }
}
