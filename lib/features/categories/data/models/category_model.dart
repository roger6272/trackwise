import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/category.dart';

/// Data model for Category entity with Firestore serialization.
///
/// Extends the domain Category entity and adds conversion methods for Firestore.
/// Handles field name mapping between Firestore (snake_case) and Dart (camelCase).
class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.userId,
    required super.order,
    required super.createdAt,
    required super.lastUpdated,
    super.deletedAt,
  });

  /// Creates a CategoryModel from a Firestore DocumentSnapshot.
  ///
  /// Maps Firestore field names to Dart property names:
  /// - category_name → name
  /// - uid (DocumentReference) → userId (String)
  /// - created_time → createdAt
  /// - last_updated → lastUpdated
  /// - deleted_at → deletedAt
  ///
  /// Provides sensible defaults for missing fields:
  /// - order: 0
  /// - timestamps: epoch 0 or current time
  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle uid as DocumentReference (FlutterFlow pattern) or String
    String userId = '';
    final uidField = data['uid'];
    if (uidField is DocumentReference) {
      userId = uidField.id;
    } else if (uidField is String) {
      userId = uidField;
    }

    return CategoryModel(
      id: doc.id,
      name: data['category_name'] as String? ?? '',
      userId: userId,
      order: data['order'] as int? ?? 0,
      createdAt: _parseDateTime(data['created_time']),
      lastUpdated: _parseDateTime(data['last_updated']),
      deletedAt: _parseNullableDateTime(data['deleted_at']),
    );
  }

  /// Parse DateTime from various Firestore formats (Timestamp, int, DateTime)
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  /// Parse nullable DateTime - returns null if value is null or 0
  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      if (value == 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  /// Converts this CategoryModel to a Firestore-compatible map.
  ///
  /// Maps Dart property names to Firestore field names (snake_case).
  /// Note: The document ID is not included as it's set separately.
  /// Note: userId is handled separately in the datasource as a DocumentReference.
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'category_name': name,
      'order': order,
      'created_time': createdAt.millisecondsSinceEpoch,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
    };
    if (deletedAt != null) {
      map['deleted_at'] = deletedAt!.millisecondsSinceEpoch;
    }
    return map;
  }

  /// Converts this model to a domain entity.
  Category toEntity() => this;

  /// Creates an ItemModel from an Item entity.
  factory CategoryModel.fromEntity(Category category) {
    return CategoryModel(
      id: category.id,
      name: category.name,
      userId: category.userId,
      order: category.order,
      createdAt: category.createdAt,
      lastUpdated: category.lastUpdated,
      deletedAt: category.deletedAt,
    );
  }
}
