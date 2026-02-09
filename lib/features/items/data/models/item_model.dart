import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/item.dart';

/// Data model for Item entity with Firestore serialization.
///
/// Extends the domain Item entity and adds conversion methods for Firestore.
/// Handles field name mapping between Firestore (snake_case) and Dart (camelCase),
/// timestamp conversion (int milliseconds ↔ DateTime), and enum serialization.
class ItemModel extends Item {
  const ItemModel({
    required super.id,
    required super.name,
    required super.count,
    required super.todayCount,
    required super.incrementBy,
    required super.reminder,
    required super.reminderValue,
    super.lastResetTime,
    super.resetNumber,
    required super.lastUpdated,
    required super.userId,
    super.deletedAt,
    super.order,
    super.initialCount,
    super.goal,
    super.categoryId,
    super.categoryOrder,
    super.deviceItemId,
    super.cycleNames,
  });

  /// Creates an ItemModel from a Firestore DocumentSnapshot.
  ///
  /// Maps Firestore field names to Dart property names:
  /// - item_name → name
  /// - todaycount → todayCount
  /// - increment_by → incrementBy
  /// - reminder_value → reminderValue
  /// - uid (DocumentReference) → userId (String)
  ///
  /// Converts timestamps from Firestore Timestamp or int to DateTime.
  /// Converts reminder from String to ReminderType enum.
  ///
  /// Provides sensible defaults for missing fields:
  /// - count: 0
  /// - todayCount: 0
  /// - incrementBy: 1
  /// - reminder: ReminderType.none
  /// - reminderValue: 0
  /// - timestamps: epoch 0
  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // FlutterFlow stores uid as DocumentReference to users collection
    // Extract the user ID from the reference path
    String userId = '';
    final uidField = data['uid'];
    if (uidField is DocumentReference) {
      userId = uidField.id;
    } else if (uidField is String) {
      userId = uidField;
    }

    return ItemModel(
      id: doc.id,
      name: data['item_name'] as String? ?? '',
      count: data['count'] as int? ?? 0,
      todayCount: data['todaycount'] as int? ?? 0,
      incrementBy: data['increment_by'] as int? ?? 1,
      reminder: _reminderFromString(data['reminder'] as String?),
      reminderValue: data['reminder_value'] as int? ?? 0,
      lastResetTime: _parseNullableDateTime(data['lastResetTime']),
      resetNumber: data['reset_number'] as int? ?? 0,
      lastUpdated: _parseDateTime(data['lastUpdated']),
      userId: userId,
      deletedAt: _parseNullableDateTime(data['deletedAt']),
      order: data['order'] as int? ?? 0,
      initialCount: data['initial_count'] as int? ?? 0,
      goal: data['goal'] as int?,
      categoryId: data['category_id'] as String?,
      categoryOrder: data['category_order'] as int? ?? 0,
      deviceItemId: data['device_item_id'] as int?,
      cycleNames: (data['cycle_names'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
    );
  }

  /// Parse DateTime from various Firestore formats (Timestamp, int, DateTime)
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Parse nullable DateTime - returns null if value is null or 0 (epoch)
  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      // Treat 0 as null (never set) - epoch 0 means "no reset"
      if (value == 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  /// Converts this ItemModel to a Firestore-compatible map.
  ///
  /// Maps Dart property names to Firestore field names (snake_case).
  /// Converts DateTime timestamps to int milliseconds.
  /// Converts ReminderType enum to uppercase String.
  ///
  /// Note: The document ID is not included in the map as it's set separately
  /// when writing to Firestore.
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'item_name': this.name,
      'count': this.count,
      'todaycount': this.todayCount,
      'increment_by': this.incrementBy,
      'reminder': _reminderToString(this.reminder),
      'reminder_value': this.reminderValue,
      'lastUpdated': this.lastUpdated.millisecondsSinceEpoch,
      'user_id': this.userId,
      'order': this.order,
      'initial_count': this.initialCount,
      'reset_number': this.resetNumber,
      'category_order': this.categoryOrder,
      'cycle_names': this.cycleNames,
    };
    if (this.lastResetTime != null) {
      map['lastResetTime'] = this.lastResetTime!.millisecondsSinceEpoch;
    }
    if (this.deletedAt != null) {
      map['deletedAt'] = this.deletedAt!.millisecondsSinceEpoch;
    }
    if (this.goal != null) {
      map['goal'] = this.goal!;
    }
    if (this.categoryId != null) {
      map['category_id'] = this.categoryId!;
    }
    if (this.deviceItemId != null) {
      map['device_item_id'] = this.deviceItemId!;
    }
    return map;
  }

  /// Converts a Firestore reminder string to ReminderType enum.
  ///
  /// Firestore stores enums as uppercase strings: "NONE", "TARGET", "INTERVAL"
  /// Defaults to ReminderType.none for null or unrecognized values.
  static ReminderType _reminderFromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'TARGET':
        return ReminderType.target;
      case 'INTERVAL':
        return ReminderType.interval;
      default:
        return ReminderType.none;
    }
  }

  /// Converts a ReminderType enum to Firestore string format.
  ///
  /// Returns uppercase string values for Firestore storage.
  static String _reminderToString(ReminderType reminder) {
    switch (reminder) {
      case ReminderType.target:
        return 'TARGET';
      case ReminderType.interval:
        return 'INTERVAL';
      case ReminderType.none:
        return 'NONE';
    }
  }

  /// Creates a copy of this ItemModel with the given fields replaced.
  ///
  /// Unlike Item.copyWith which returns Item, this returns ItemModel
  /// so Firestore serialization methods remain available.
  @override
  ItemModel copyWith({
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
  }) {
    return ItemModel(
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
    );
  }

  /// Converts this model to a domain entity.
  ///
  /// Since ItemModel extends Item, this is a simple cast.
  /// Useful for explicit conversions in the repository layer.
  Item toEntity() => this;
}
