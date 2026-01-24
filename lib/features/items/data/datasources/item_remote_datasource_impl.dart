import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/item.dart' show ReminderType;
import '../models/item_model.dart';
import 'item_remote_datasource.dart';

/// Helper to parse ReminderType from string.
ReminderType _parseReminderType(String? value) {
  if (value == null) return ReminderType.none;
  return ReminderType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ReminderType.none,
  );
}

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

  /// Ensures user document exists in Firestore.
  /// This handles the case where a user was authenticated via cached session
  /// and the user document was never created.
  Future<void> _ensureUserDocument(String userId) async {
    debugPrint('📦 _ensureUserDocument: checking for $userId');
    final userDoc = firestore.collection('users').doc(userId);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      debugPrint('📦 _ensureUserDocument: document MISSING, creating...');
      // Get current user from Firebase Auth to populate the document
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        await userDoc.set({
          'uid': userId,
          'email': currentUser.email,
          'display_name': currentUser.displayName,
          'photo_url': currentUser.photoURL,
          'created_time': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Created user document for $userId from items datasource');
      } else {
        // Fallback: create minimal document
        await userDoc.set({
          'uid': userId,
          'created_time': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Created minimal user document for $userId');
      }
    } else {
      debugPrint('📦 _ensureUserDocument: document EXISTS');
    }
  }

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
      debugPrint('📡 watchItems: userId=$userId, userRef=${userRef.path}');
      return firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .orderBy('order')
          .snapshots()
          .map((snapshot) {
            debugPrint('📡 watchItems snapshot: ${snapshot.docs.length} docs');
            final items = snapshot.docs
                .map((doc) => ItemModel.fromFirestore(doc))
                .where((item) => item.deletedAt == null)
                .toList();
            debugPrint('📡 watchItems filtered: ${items.length} items');
            return items;
          })
          .handleError((error) {
        debugPrint('📡 watchItems error: $error');
        throw ServerException('Failed to watch items: $error');
      });
    } catch (e) {
      debugPrint('📡 watchItems setup error: $e');
      throw ServerException('Failed to setup items stream: $e');
    }
  }

  @override
  Future<ItemModel> createItem(ItemModel item) async {
    try {
      debugPrint('💾 createItem: userId=${item.userId}, name=${item.name}');

      // Ensure user document exists before creating item
      await _ensureUserDocument(item.userId);

      // Generate ID if empty
      final id = item.id.isEmpty
          ? firestore.collection('Item').doc().id
          : item.id;

      final userRef = firestore.collection('users').doc(item.userId);
      debugPrint('💾 createItem: id=$id, userRef=${userRef.path}');

      // Get existing items to shift their order
      final existingItems = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();
      debugPrint('💾 createItem: ${existingItems.docs.length} existing items');

      // Use batch to atomically create new item and shift existing items
      final batch = firestore.batch();

      // Shift all existing non-deleted items down by 1
      for (final doc in existingItems.docs) {
        if (doc.data()['deletedAt'] == null) {
          final currentOrder = doc.data()['order'] as int? ?? 0;
          batch.update(doc.reference, {'order': currentOrder + 1});
        }
      }

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
        order: 0, // New items go to top
        initialCount: item.initialCount,
        goal: item.goal,
        categoryId: item.categoryId,
        categoryOrder: item.categoryOrder,
      );

      // FlutterFlow stores uid as DocumentReference, not String
      final data = newItem.toFirestore();
      data.remove('user_id'); // Remove string version
      data['uid'] = userRef; // Add DocumentReference version

      batch.set(firestore.collection('Item').doc(id), data);
      await batch.commit();
      debugPrint('💾 createItem: SUCCESS - item $id created');

      return newItem;
    } on FirebaseException catch (e) {
      debugPrint('💾 createItem: FIREBASE ERROR - ${e.message}');
      throw ServerException('Failed to create item: ${e.message}');
    } catch (e) {
      debugPrint('💾 createItem: ERROR - $e');
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
        categoryId: item.categoryId,
        categoryOrder: item.categoryOrder,
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
            // Only update lastResetTime if actually provided (non-zero)
            final lastResetTimeSeconds = item['lastResetTime'] as int? ?? 0;
            final resetNumber = item['resetNumber'] as int?;

            final updateData = <String, dynamic>{
              'count': count,
              'todaycount': todaycount,
            };

            // Only include lastResetTime if it's a real value (not 0/epoch)
            if (lastResetTimeSeconds > 0) {
              updateData['lastResetTime'] = lastResetTimeSeconds * 1000;
            }

            // Only include resetNumber if provided
            if (resetNumber != null) {
              updateData['reset_number'] = resetNumber;
            }

            batch.update(itemRef, updateData);
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

      // Get existing non-deleted items to shift their order
      final existingItems = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();

      // Use batch to atomically restore item and shift existing items
      final batch = firestore.batch();

      // Shift all existing non-deleted items down by 1 (like item creation)
      for (final doc in existingItems.docs) {
        if (doc.data()['deletedAt'] == null) {
          final currentOrder = doc.data()['order'] as int? ?? 0;
          batch.update(doc.reference, {'order': currentOrder + 1});
        }
      }

      // Restore item with order 0 (top of list)
      batch.update(firestore.collection('Item').doc(itemId), {
        'deletedAt': FieldValue.delete(),
        'order': 0,
      });

      await batch.commit();
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

  @override
  Future<void> reorderItemsInCategory(List<ItemModel> items) async {
    try {
      final batch = firestore.batch();

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final itemRef = firestore.collection('Item').doc(item.id);
        // Update both category_order and category_id (for cross-category moves)
        final updateData = <String, dynamic>{
          'category_order': i,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        };
        if (item.categoryId != null && item.categoryId!.isNotEmpty) {
          updateData['category_id'] = item.categoryId;
        } else {
          updateData['category_id'] = FieldValue.delete();
        }
        batch.update(itemRef, updateData);
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to reorder items in category: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error reordering items in category: $e');
    }
  }

  @override
  Future<void> moveItemToCategory(
    String itemId,
    String? newCategoryId,
    int newCategoryOrder,
  ) async {
    try {
      final updateData = <String, dynamic>{
        'category_order': newCategoryOrder,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };

      if (newCategoryId != null) {
        updateData['category_id'] = newCategoryId;
      } else {
        updateData['category_id'] = FieldValue.delete();
      }

      await firestore.collection('Item').doc(itemId).update(updateData);
    } on FirebaseException catch (e) {
      throw ServerException('Failed to move item to category: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error moving item to category: $e');
    }
  }

  @override
  Future<int> getMaxCategoryOrder(String userId, String? categoryId) async {
    try {
      final userRef = firestore.collection('users').doc(userId);
      Query query = firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef);

      if (categoryId != null) {
        query = query.where('category_id', isEqualTo: categoryId);
      } else {
        // For uncategorized items, we need to check for null category_id
        // Firestore doesn't have a direct "is null" query, so we'll get all
        // items and filter client-side
        final snapshot = await firestore
            .collection('Item')
            .where('uid', isEqualTo: userRef)
            .get();

        int maxOrder = -1;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['deletedAt'] == null && data['category_id'] == null) {
            final order = data['category_order'] as int? ?? 0;
            if (order > maxOrder) {
              maxOrder = order;
            }
          }
        }
        return maxOrder;
      }

      final snapshot = await query.get();

      int maxOrder = -1;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['deletedAt'] == null) {
          final order = data['category_order'] as int? ?? 0;
          if (order > maxOrder) {
            maxOrder = order;
          }
        }
      }

      return maxOrder;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get max category order: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error getting max category order: $e');
    }
  }

  @override
  Future<List<ItemModel>> resetAllItems(String userId) async {
    try {
      final now = DateTime.now();
      final nowMillis = now.millisecondsSinceEpoch;

      // Get all active items for the user
      final userRef = firestore.collection('users').doc(userId);
      final snapshot = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();

      final activeItems = snapshot.docs
          .where((doc) => doc.data()['deletedAt'] == null)
          .toList();

      if (activeItems.isEmpty) {
        return [];
      }

      // Use batch for atomic updates
      final batch = firestore.batch();
      final resetItems = <ItemModel>[];

      for (final doc in activeItems) {
        final data = doc.data();
        final currentResetNumber = data['resetNumber'] as int? ?? 0;
        final newResetNumber = currentResetNumber + 1;

        // Extract item's userId from DocumentReference
        String itemUserId = '';
        final uidField = data['uid'];
        if (uidField is DocumentReference) {
          itemUserId = uidField.id;
        } else if (uidField is String) {
          itemUserId = uidField;
        }

        // Update item document
        final itemRef = firestore.collection('Item').doc(doc.id);
        batch.update(itemRef, {
          'count': 0,
          'todayCount': 0,
          'resetNumber': newResetNumber,
          'lastResetTime': nowMillis,
          'lastUpdated': nowMillis,
        });

        // Create reset event log
        final eventRef = firestore.collection('EventLog').doc();
        batch.set(eventRef, {
          'created_time': Timestamp.fromDate(now),
          'item_id': doc.id,
          'eventName': 'reset',
          'increment': 0,
          'currentCount': 0,
          'resetNumber': newResetNumber,
          'user_id': itemUserId,
        });

        // Build updated ItemModel for return
        resetItems.add(ItemModel(
          id: doc.id,
          name: data['item_name'] as String? ?? '',
          count: 0,
          todayCount: 0,
          incrementBy: data['increment_by'] as int? ?? 1,
          reminder: _parseReminderType(data['reminder'] as String?),
          reminderValue: data['reminder_value'] as int? ?? 0,
          lastResetTime: now,
          resetNumber: newResetNumber,
          lastUpdated: now,
          userId: itemUserId,
          deletedAt: null,
          order: data['order'] as int? ?? 0,
          initialCount: data['initial_count'] as int? ?? 0,
          goal: data['goal'] as int?,
          categoryId: data['category_id'] as String?,
          categoryOrder: data['category_order'] as int? ?? 0,
        ));
      }

      await batch.commit();
      return resetItems;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to reset all items: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error resetting all items: $e');
    }
  }
}
