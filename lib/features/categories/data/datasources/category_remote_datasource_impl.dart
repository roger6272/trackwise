import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/logger.dart';

import '../../../../core/error/exceptions.dart';
import '../models/category_model.dart';
import 'category_remote_datasource.dart';

/// Firestore implementation of [CategoryRemoteDataSource].
@LazySingleton(as: CategoryRemoteDataSource)
class CategoryRemoteDataSourceImpl implements CategoryRemoteDataSource {
  final FirebaseFirestore firestore;

  /// Firestore collection name for categories.
  static const String _collection = 'Category';

  /// Firestore collection name for items (for counting).
  static const String _itemsCollection = 'Item';

  CategoryRemoteDataSourceImpl(this.firestore);

  @override
  Future<List<CategoryModel>> getCategories(String userId) async {
    try {
      final userRef = firestore.collection('users').doc(userId);
      final snapshot = await firestore
          .collection(_collection)
          .where('uid', isEqualTo: userRef)
          .orderBy('order')
          .get();

      return snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .where((category) => category.deletedAt == null)
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to fetch categories: ${e.message}');
    }
  }

  @override
  Stream<List<CategoryModel>> watchCategories(String userId) {
    final userRef = firestore.collection('users').doc(userId);
    return firestore
        .collection(_collection)
        .where('uid', isEqualTo: userRef)
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => CategoryModel.fromFirestore(doc))
              .where((category) => category.deletedAt == null)
              .toList();
          // Sort client-side to avoid needing composite index
          categories.sort((a, b) => a.order.compareTo(b.order));
          return categories;
        })
        .handleError((error, stackTrace) {
          AppLogger.debug('watchCategories stream error: $error');
          AppLogger.debug('Stack trace: $stackTrace');
          throw ServerException('Failed to watch categories: $error');
        });
  }

  @override
  Future<CategoryModel> createCategory(CategoryModel category) async {
    try {
      final userRef = firestore.collection('users').doc(category.userId);
      final data = category.toFirestore();
      data['uid'] = userRef; // Store as DocumentReference

      final docRef = await firestore.collection(_collection).add(data);
      final doc = await docRef.get();

      return CategoryModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw ServerException('Failed to create category: ${e.message}');
    }
  }

  @override
  Future<CategoryModel> updateCategory(CategoryModel category) async {
    try {
      final data = category.toFirestore();

      await firestore.collection(_collection).doc(category.id).update(data);

      final doc = await firestore.collection(_collection).doc(category.id).get();
      return CategoryModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw ServerException('Failed to update category: ${e.message}');
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    try {
      // Soft delete by setting deletedAt
      await firestore.collection(_collection).doc(categoryId).update({
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Set categoryId to null for all items in this category
      final itemsSnapshot = await firestore
          .collection(_itemsCollection)
          .where('category_id', isEqualTo: categoryId)
          .get();

      final batch = firestore.batch();
      for (final doc in itemsSnapshot.docs) {
        batch.update(doc.reference, {'category_id': FieldValue.delete()});
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to delete category: ${e.message}');
    }
  }

  @override
  Future<void> reorderCategories(List<CategoryModel> categories) async {
    try {
      final batch = firestore.batch();

      for (final category in categories) {
        final docRef = firestore.collection(_collection).doc(category.id);
        batch.update(docRef, {
          'order': category.order,
          'last_updated': DateTime.now().millisecondsSinceEpoch,
        });
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to reorder categories: ${e.message}');
    }
  }

  @override
  Future<bool> categoryNameExists(
    String userId,
    String name, {
    String? excludeId,
  }) async {
    try {
      final userRef = firestore.collection('users').doc(userId);
      final normalizedName = _normalizeName(name);

      final snapshot = await firestore
          .collection(_collection)
          .where('uid', isEqualTo: userRef)
          .get();

      for (final doc in snapshot.docs) {
        final category = CategoryModel.fromFirestore(doc);
        if (category.deletedAt != null) continue;
        if (excludeId != null && category.id == excludeId) continue;
        if (_normalizeName(category.name) == normalizedName) {
          return true;
        }
      }

      return false;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to check category name: ${e.message}');
    }
  }

  @override
  Future<int> getItemCountForCategory(String? categoryId, String userId) async {
    try {
      final userRef = firestore.collection('users').doc(userId);

      Query query = firestore
          .collection(_itemsCollection)
          .where('uid', isEqualTo: userRef);

      if (categoryId == null) {
        // Count uncategorized items (where category_id doesn't exist or is null)
        // Firestore doesn't support "field doesn't exist" directly,
        // so we'll need to fetch and filter
        final snapshot = await query.get();
        return snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final catId = data['category_id'];
          final deletedAt = data['deletedAt'];
          return (catId == null || catId == '') && deletedAt == null;
        }).length;
      } else {
        // Count items with specific category
        final snapshot = await query
            .where('category_id', isEqualTo: categoryId)
            .get();
        return snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['deletedAt'] == null;
        }).length;
      }
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get item count: ${e.message}');
    }
  }

  @override
  Future<int> getNextOrderValue(String userId) async {
    try {
      final userRef = firestore.collection('users').doc(userId);
      final snapshot = await firestore
          .collection(_collection)
          .where('uid', isEqualTo: userRef)
          .get();

      if (snapshot.docs.isEmpty) {
        return 0;
      }

      // Find max order value client-side to avoid needing composite index
      int maxOrder = -1;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['deleted_at'] == null) {
          final order = data['order'] as int? ?? 0;
          if (order > maxOrder) {
            maxOrder = order;
          }
        }
      }

      return maxOrder + 1;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get next order value: ${e.message}');
    }
  }

  /// Normalizes a category name for comparison.
  /// Trims whitespace and converts to lowercase.
  String _normalizeName(String name) {
    return name.trim().toLowerCase();
  }
}
