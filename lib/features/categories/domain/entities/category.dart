import 'package:equatable/equatable.dart';

/// Category entity for organizing items into groups.
///
/// Categories are user-created groupings that help organize inventory items.
/// Each item can belong to one category (or be uncategorized).
///
/// Domain layer entity - pure Dart with no Flutter/Firebase dependencies.
class Category extends Equatable {
  /// Unique identifier matching Firestore document ID
  final String id;

  /// User-defined category name (max 30 characters, normalized)
  final String name;

  /// Firebase UID of the category owner
  final String userId;

  /// Display order for sorting categories in the list (0-indexed)
  final int order;

  /// Timestamp when category was created
  final DateTime createdAt;

  /// Timestamp of last modification
  final DateTime lastUpdated;

  /// Timestamp when category was soft-deleted, null if active.
  /// Categories with non-null deletedAt are hidden from normal queries.
  final DateTime? deletedAt;

  const Category({
    required this.id,
    required this.name,
    required this.userId,
    required this.order,
    required this.createdAt,
    required this.lastUpdated,
    this.deletedAt,
  });

  /// Creates a copy of this category with the given fields replaced.
  Category copyWith({
    String? id,
    String? name,
    String? userId,
    int? order,
    DateTime? createdAt,
    DateTime? lastUpdated,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        userId,
        order,
        createdAt,
        lastUpdated,
        deletedAt,
      ];

  @override
  String toString() {
    return 'Category(id: $id, name: $name, userId: $userId, order: $order, '
        'createdAt: $createdAt, lastUpdated: $lastUpdated, deletedAt: $deletedAt)';
  }
}
