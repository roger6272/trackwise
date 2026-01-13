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
    required super.lastResetTime,
    required super.lastUpdated,
    required super.userId,
  });

  /// Creates an ItemModel from a Firestore DocumentSnapshot.
  ///
  /// Maps Firestore field names to Dart property names:
  /// - item_name → name
  /// - todaycount → todayCount
  /// - increment_by → incrementBy
  /// - reminder_value → reminderValue
  /// - user_id → userId
  ///
  /// Converts timestamps from int milliseconds to DateTime.
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
    return ItemModel(
      id: doc.id,
      name: data['item_name'] as String,
      count: data['count'] as int? ?? 0,
      todayCount: data['todaycount'] as int? ?? 0,
      incrementBy: data['increment_by'] as int? ?? 1,
      reminder: _reminderFromString(data['reminder'] as String?),
      reminderValue: data['reminder_value'] as int? ?? 0,
      lastResetTime: DateTime.fromMillisecondsSinceEpoch(
        data['lastResetTime'] as int? ?? 0,
      ),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        data['lastUpdated'] as int? ?? 0,
      ),
      userId: data['user_id'] as String,
    );
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
    return {
      'item_name': this.name,
      'count': this.count,
      'todaycount': this.todayCount,
      'increment_by': this.incrementBy,
      'reminder': _reminderToString(this.reminder),
      'reminder_value': this.reminderValue,
      'lastResetTime': this.lastResetTime.millisecondsSinceEpoch,
      'lastUpdated': this.lastUpdated.millisecondsSinceEpoch,
      'user_id': this.userId,
    };
  }

  /// Converts a Firestore reminder string to ReminderType enum.
  ///
  /// Firestore stores enums as uppercase strings: "NONE", "TARGET", "INTERVAL", "EVERY_TIME"
  /// Defaults to ReminderType.none for null or unrecognized values.
  static ReminderType _reminderFromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'TARGET':
        return ReminderType.target;
      case 'INTERVAL':
        return ReminderType.interval;
      case 'EVERY_TIME':
        return ReminderType.everyTime;
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
      case ReminderType.everyTime:
        return 'EVERY_TIME';
      case ReminderType.none:
        return 'NONE';
    }
  }

  /// Converts this model to a domain entity.
  ///
  /// Since ItemModel extends Item, this is a simple cast.
  /// Useful for explicit conversions in the repository layer.
  Item toEntity() => this;
}
