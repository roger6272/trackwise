import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/event_log.dart';

/// Data model for EventLog entity with Firestore serialization.
///
/// Extends the domain EventLog entity and adds conversion methods for Firestore.
/// Handles field name mapping between Firestore and Dart, and type conversions
/// for Timestamp and DocumentReference fields.
///
/// Firestore schema (existing):
/// - `created_time`: Timestamp
/// - `item`: DocumentReference to /Item/{itemId}
/// - `event_name`: String
/// - `increment`: int
/// - `currentcount`: int (no underscore)
/// - `uid`: DocumentReference to /users/{userId}
/// - `id`: String
class EventLogModel extends EventLog {
  const EventLogModel({
    required super.id,
    required super.createdTime,
    required super.itemId,
    required super.eventName,
    required super.increment,
    required super.currentCount,
    required super.userId,
  });

  /// Creates an EventLogModel from a Firestore DocumentSnapshot.
  ///
  /// Maps Firestore field names to Dart property names:
  /// - created_time (Timestamp) → createdTime (DateTime)
  /// - item (DocumentReference) → itemId (String - extracted from path)
  /// - event_name → eventName
  /// - increment → increment
  /// - currentcount → currentCount
  /// - uid (DocumentReference) → userId (String - extracted from path)
  ///
  /// Provides sensible defaults for missing fields.
  factory EventLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Extract itemId from DocumentReference
    String itemId = '';
    final itemRef = data['item'];
    if (itemRef is DocumentReference) {
      itemId = itemRef.id;
    } else if (itemRef is String) {
      itemId = itemRef;
    }

    // Extract userId from DocumentReference
    String userId = '';
    final uidRef = data['uid'];
    if (uidRef is DocumentReference) {
      userId = uidRef.id;
    } else if (uidRef is String) {
      userId = uidRef;
    }

    // Parse created_time from Timestamp
    DateTime createdTime = DateTime.fromMillisecondsSinceEpoch(0);
    final createdTimeValue = data['created_time'];
    if (createdTimeValue is Timestamp) {
      createdTime = createdTimeValue.toDate();
    } else if (createdTimeValue is int) {
      createdTime = DateTime.fromMillisecondsSinceEpoch(createdTimeValue);
    }

    return EventLogModel(
      id: doc.id,
      createdTime: createdTime,
      itemId: itemId,
      eventName: data['event_name'] as String? ?? '',
      increment: data['increment'] as int? ?? 0,
      currentCount: data['currentcount'] as int? ?? 0,
      userId: userId,
    );
  }

  /// Creates an EventLogModel from a domain EventLog entity.
  ///
  /// Used when converting entities from the domain layer for persistence.
  factory EventLogModel.fromEntity(EventLog entity) {
    return EventLogModel(
      id: entity.id,
      createdTime: entity.createdTime,
      itemId: entity.itemId,
      eventName: entity.eventName,
      increment: entity.increment,
      currentCount: entity.currentCount,
      userId: entity.userId,
    );
  }

  /// Converts this EventLogModel to a Firestore-compatible map.
  ///
  /// Requires FirebaseFirestore instance to create DocumentReferences
  /// for the `item` and `uid` fields.
  ///
  /// Firestore field mapping:
  /// - created_time: Timestamp
  /// - item: DocumentReference to /Item/{itemId}
  /// - event_name: String
  /// - increment: int
  /// - currentcount: int
  /// - uid: DocumentReference to /users/{userId}
  /// - id: String (document ID)
  Map<String, dynamic> toFirestore(FirebaseFirestore firestore) {
    return {
      'created_time': Timestamp.fromDate(createdTime),
      'item': firestore.doc('/Item/$itemId'),
      'event_name': eventName,
      'increment': increment,
      'currentcount': currentCount,
      'uid': firestore.doc('/users/$userId'),
      'id': id,
    };
  }

  /// Converts this model to a domain entity.
  ///
  /// Since EventLogModel extends EventLog, this is a simple cast.
  /// Useful for explicit conversions in the repository layer.
  EventLog toEntity() => this;
}
