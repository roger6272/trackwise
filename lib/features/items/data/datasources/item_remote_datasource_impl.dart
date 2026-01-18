import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../models/item_model.dart';
import 'item_remote_datasource.dart';

/// Concrete implementation of ItemRemoteDataSource using Firestore.
///
/// Handles all Firestore operations for the Item feature. Converts Firestore
/// documents to ItemModel objects and vice versa. All methods throw
/// [ServerException] on failure.
///
/// Uses Injectable for dependency injection with FirebaseFirestore instance.
@LazySingleton(as: ItemRemoteDataSource)
class ItemRemoteDataSourceImpl implements ItemRemoteDataSource {
  final FirebaseFirestore firestore;

  ItemRemoteDataSourceImpl(this.firestore);

  @override
  Future<List<ItemModel>> getItems(String userId) async {
    try {
      // FlutterFlow stores uid as DocumentReference to users collection
      final userRef = firestore.collection('users').doc(userId);
      final snapshot = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .orderBy('order')
          .get();

      return snapshot.docs
          .map((doc) => ItemModel.fromFirestore(doc))
          .where((item) => item.deletedAt == null) // Filter out soft-deleted
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to fetch items: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error fetching items: $e');
    }
  }

  @override
  Future<ItemModel> getItem(String itemId) async {
    try {
      final doc = await firestore.collection('Item').doc(itemId).get();

      if (!doc.exists) {
        throw ServerException('Item not found: $itemId');
      }

      return ItemModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw ServerException('Failed to fetch item: ${e.message}');
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error fetching item: $e');
    }
  }

  @override
  Stream<List<ItemModel>> watchItems(String userId) {
    try {
      // FlutterFlow stores uid as DocumentReference to users collection
      final userRef = firestore.collection('users').doc(userId);
      return firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .orderBy('order')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ItemModel.fromFirestore(doc))
              .where((item) => item.deletedAt == null) // Filter out soft-deleted
              .toList())
          .handleError((error) {
        throw ServerException('Failed to watch items: $error');
      });
    } catch (e) {
      throw ServerException('Failed to setup items stream: $e');
    }
  }

  @override
  Future<ItemModel> createItem(ItemModel item) async {
    try {
      // Generate ID if empty
      final id = item.id.isEmpty
          ? firestore.collection('Item').doc().id
          : item.id;

      // Query to get the count of existing items for this user to set order
      final userRef = firestore.collection('users').doc(item.userId);
      final existingItems = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();
      final newOrder = existingItems.docs
          .where((doc) => doc.data()['deletedAt'] == null)
          .length;

      final now = DateTime.now();
      final newItem = ItemModel(
        id: id,
        name: item.name,
        count: item.count,
        todayCount: item.todayCount,
        incrementBy: item.incrementBy,
        reminder: item.reminder,
        reminderValue: item.reminderValue,
        lastResetTime: item.lastResetTime,
        lastUpdated: now,
        userId: item.userId,
        order: newOrder,
        initialCount: item.initialCount,
        goal: item.goal,
      );

      // FlutterFlow stores uid as DocumentReference, not String
      final data = newItem.toFirestore();
      data.remove('user_id'); // Remove string version
      data['uid'] = userRef; // Add DocumentReference version

      await firestore.collection('Item').doc(id).set(data);

      return newItem;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to create item: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error creating item: $e');
    }
  }

  @override
  Future<ItemModel> updateItem(ItemModel item) async {
    try {
      final updatedItem = ItemModel(
        id: item.id,
        name: item.name,
        count: item.count,
        todayCount: item.todayCount,
        incrementBy: item.incrementBy,
        reminder: item.reminder,
        reminderValue: item.reminderValue,
        lastResetTime: item.lastResetTime,
        lastUpdated: DateTime.now(), // Update timestamp
        userId: item.userId,
        order: item.order,
        initialCount: item.initialCount,
        goal: item.goal,
      );

      // FlutterFlow stores uid as DocumentReference, not String
      final userRef = firestore.collection('users').doc(item.userId);
      final data = updatedItem.toFirestore();
      data.remove('user_id'); // Remove string version
      data['uid'] = userRef; // Add DocumentReference version

      debugPrint('🔶 Firestore update data: $data');
      await firestore.collection('Item').doc(item.id).update(data);

      return updatedItem;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to update item: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error updating item: $e');
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    try {
      // Soft delete: set deletedAt timestamp instead of actually deleting
      // Item and EventLogs will be permanently deleted after 90 days by Cloud Function
      await firestore.collection('Item').doc(itemId).update({
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to delete item: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error deleting item: $e');
    }
  }

  @override
  Future<ItemModel> incrementItem(String itemId, int amount) async {
    try {
      final doc = await firestore.collection('Item').doc(itemId).get();
      if (!doc.exists) {
        throw ServerException('Item not found: $itemId');
      }

      final item = ItemModel.fromFirestore(doc);
      final updatedItem = ItemModel(
        id: item.id,
        name: item.name,
        count: item.count + amount,
        todayCount: item.todayCount + amount,
        incrementBy: item.incrementBy,
        reminder: item.reminder,
        reminderValue: item.reminderValue,
        lastResetTime: item.lastResetTime,
        lastUpdated: DateTime.now(),
        userId: item.userId,
        order: item.order,
        initialCount: item.initialCount,
        goal: item.goal,
      );

      // FlutterFlow stores uid as DocumentReference, not String
      final userRef = firestore.collection('users').doc(item.userId);
      final data = updatedItem.toFirestore();
      data.remove('user_id'); // Remove string version
      data['uid'] = userRef; // Add DocumentReference version

      await firestore.collection('Item').doc(itemId).update(data);

      return updatedItem;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to increment item: ${e.message}');
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error incrementing item: $e');
    }
  }

  @override
  Future<void> resetDailyCount(String itemId) async {
    try {
      await firestore.collection('Item').doc(itemId).update({
        'todaycount': 0,
        'lastResetTime': DateTime.now().millisecondsSinceEpoch,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to reset daily count: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error resetting daily count: $e');
    }
  }

  @override
  Future<void> batchUpdateCounts(
    String userId,
    List<Map<String, dynamic>> itemData,
  ) async {
    try {
      // Get existing item IDs for this user
      final userRef = firestore.collection('users').doc(userId);
      final existingSnapshot = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();

      final existingItemIds = existingSnapshot.docs.map((doc) => doc.id).toSet();

      final batch = firestore.batch();
      int updateCount = 0;

      for (final item in itemData) {
        if (item is Map<String, dynamic>) {
          final itemId = item['id'] as String?;
          if (itemId == null) continue;

          if (existingItemIds.contains(itemId)) {
            final itemRef = firestore.collection('Item').doc(itemId);
            final count = item['count'] as int? ?? 0;
            final todaycount = item['todaycount'] as int? ?? 0;
            // ESP32 sends timestamp in seconds, convert to milliseconds
            final lastResetTimeSeconds = item['lastResetTime'] as int? ?? 0;

            batch.update(itemRef, {
              'count': count,
              'todaycount': todaycount,
              'lastResetTime': lastResetTimeSeconds * 1000,
            });
            updateCount++;
          }
        }
      }

      if (updateCount > 0) {
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      throw ServerException('Failed to batch update counts: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error batch updating counts: $e');
    }
  }

  @override
  Future<List<ItemModel>> getDeletedItems(String userId) async {
    try {
      debugPrint('🗑️ Datasource: getDeletedItems called for user $userId');
      final userRef = firestore.collection('users').doc(userId);
      debugPrint('🗑️ Datasource: Querying Firestore...');
      final snapshot = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();
      debugPrint('🗑️ Datasource: Got ${snapshot.docs.length} total items');

      final deletedItems = snapshot.docs
          .map((doc) => ItemModel.fromFirestore(doc))
          .where((item) => item.deletedAt != null) // Only soft-deleted items
          .toList();
      debugPrint('🗑️ Datasource: Found ${deletedItems.length} deleted items');
      return deletedItems;
    } on FirebaseException catch (e) {
      debugPrint('🗑️ Datasource: FirebaseException - ${e.message}');
      throw ServerException('Failed to fetch deleted items: ${e.message}');
    } catch (e) {
      debugPrint('🗑️ Datasource: Exception - $e');
      throw ServerException('Unexpected error fetching deleted items: $e');
    }
  }

  @override
  Future<void> restoreItem(String itemId) async {
    try {
      // Get the item to find its userId
      final itemDoc = await firestore.collection('Item').doc(itemId).get();
      if (!itemDoc.exists) {
        throw ServerException('Item not found: $itemId');
      }

      final itemData = itemDoc.data()!;
      final userRef = itemData['uid'] as DocumentReference;

      // Count existing non-deleted items to determine new order
      final existingItems = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();
      final newOrder = existingItems.docs
          .where((doc) => doc.data()['deletedAt'] == null)
          .length;

      // Restore item with new order at end of list
      await firestore.collection('Item').doc(itemId).update({
        'deletedAt': FieldValue.delete(),
        'order': newOrder,
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to restore item: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error restoring item: $e');
    }
  }

  @override
  Future<void> reorderItems(List<ItemModel> items) async {
    try {
      final batch = firestore.batch();

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final itemRef = firestore.collection('Item').doc(item.id);
        batch.update(itemRef, {'order': i});
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to reorder items: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error reordering items: $e');
    }
  }
}
