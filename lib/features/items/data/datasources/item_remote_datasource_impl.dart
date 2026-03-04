import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/constants.dart';
import '../../../../core/utils/logger.dart';

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

  /// Cached userId to avoid redundant Firestore reads on every createItem call.
  /// Scoped to userId so cache is invalidated on account switch.
  String? _verifiedUserId;

  /// Ensures user document exists in Firestore.
  /// This handles the case where a user was authenticated via cached session
  /// and the user document was never created.
  Future<void> _ensureUserDocument(String userId) async {
    if (_verifiedUserId == userId) return;

    AppLogger.debug('_ensureUserDocument: checking for $userId');
    final userDoc = firestore.collection('users').doc(userId);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      AppLogger.debug('_ensureUserDocument: document MISSING, creating...');
      // Try to get current user from Firebase Auth to populate the document
      // Wrapped in try-catch for test environments where Firebase may not be initialized
      User? currentUser;
      try {
        currentUser = FirebaseAuth.instance.currentUser;
      } catch (_) {
        // Firebase not initialized (e.g., in tests), fall back to minimal document
        currentUser = null;
      }

      if (currentUser != null && currentUser.uid == userId) {
        await userDoc.set({
          'uid': userId,
          'email': currentUser.email,
          'display_name': currentUser.displayName,
          'photo_url': currentUser.photoURL,
          'created_time': FieldValue.serverTimestamp(),
        });
        AppLogger.debug('Created user document for $userId from items datasource');
      } else {
        // Fallback: create minimal document
        await userDoc.set({
          'uid': userId,
          'created_time': FieldValue.serverTimestamp(),
        });
        AppLogger.debug('Created minimal user document for $userId');
      }
    } else {
      AppLogger.debug('_ensureUserDocument: document EXISTS');
    }

    _verifiedUserId = userId;
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
  Stream<ItemModel> watchItem(String itemId) {
    try {
      return firestore
          .collection('Item')
          .doc(itemId)
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) {
              throw ServerException('Item not found: $itemId');
            }
            return ItemModel.fromFirestore(snapshot);
          })
          .handleError((error) {
        throw ServerException('Failed to watch item: $error');
      });
    } catch (e) {
      throw ServerException('Failed to setup item stream: $e');
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
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ItemModel.fromFirestore(doc))
                .where((item) => item.deletedAt == null)
                .toList();
          })
          .handleError((error) {
        throw ServerException('Failed to watch items: $error');
      });
    } catch (e) {
      throw ServerException('Failed to setup items stream: $e');
    }
  }

  /// Finds the next available deviceItemId (0-99) for a user.
  ///
  /// Scans all non-deleted items and finds the first unused ID.
  /// Throws [ServerException] if all 100 IDs are in use.
  Future<int> _getNextDeviceItemId(DocumentReference userRef) async {
    final snapshot = await firestore
        .collection('Item')
        .where('uid', isEqualTo: userRef)
        .get();

    final usedIds = snapshot.docs
        .where((doc) => doc.data()['deletedAt'] == null) // Only active items
        .map((doc) => doc.data()['device_item_id'] as int?)
        .whereType<int>()
        .toSet();

    for (int i = 0; i < 100; i++) {
      if (!usedIds.contains(i)) return i;
    }
    throw ServerException('Maximum 100 items reached');
  }

  @override
  Future<ItemModel> createItem(ItemModel item) async {
    try {
      AppLogger.debug('createItem: userId=${item.userId}, name=${item.name}');

      // Ensure user document exists before creating item
      await _ensureUserDocument(item.userId);

      // Generate ID if empty
      final id = item.id.isEmpty
          ? firestore.collection('Item').doc().id
          : item.id;

      final userRef = firestore.collection('users').doc(item.userId);

      // Generate deviceItemId for BLE communication (0-99)
      final deviceItemId = await _getNextDeviceItemId(userRef);
      AppLogger.debug('createItem: id=$id, deviceItemId=$deviceItemId, userRef=${userRef.path}');

      // Get existing items to shift their order
      final existingItems = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();
      AppLogger.debug('createItem: ${existingItems.docs.length} existing items');

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
        deviceItemId: deviceItemId, // Assigned deviceItemId for BLE
        cycleNames: item.cycleNames,
        cycleNotes: item.cycleNotes,
        claimedBy: item.claimedBy,
        claimedAt: item.claimedAt,
      );

      // FlutterFlow stores uid as DocumentReference, not String
      final data = newItem.toFirestore();
      data.remove('user_id'); // Remove string version
      data['uid'] = userRef; // Add DocumentReference version

      batch.set(firestore.collection('Item').doc(id), data);
      await batch.commit();
      AppLogger.debug('createItem: SUCCESS - item $id created');

      return newItem;
    } on FirebaseException catch (e) {
      AppLogger.debug('createItem: FIREBASE ERROR - ${e.message}');
      throw ServerException('Failed to create item: ${e.message}');
    } catch (e) {
      AppLogger.debug('createItem: ERROR - $e');
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
        deviceItemId: item.deviceItemId, // Preserve deviceItemId
        cycleNames: item.cycleNames,
        cycleNotes: item.cycleNotes,
        claimedBy: item.claimedBy,
        claimedAt: item.claimedAt,
      );

      // FlutterFlow stores uid as DocumentReference, not String
      final userRef = firestore.collection('users').doc(item.userId);
      final data = updatedItem.toFirestore();
      data.remove('user_id'); // Remove string version
      data['uid'] = userRef; // Add DocumentReference version

      AppLogger.debug('Firestore update data: $data');
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
      // Item and EventLogs will be permanently deleted after 30 days by Cloud Function
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
        count: (item.count + amount).clamp(0, AppConstants.maxCountValue),
        todayCount: (item.todayCount + amount).clamp(0, AppConstants.maxCountValue),
        incrementBy: item.incrementBy,
        reminder: item.reminder,
        reminderValue: item.reminderValue,
        lastResetTime: item.lastResetTime,
        lastUpdated: DateTime.now(),
        userId: item.userId,
        order: item.order,
        initialCount: item.initialCount,
        goal: item.goal,
        categoryId: item.categoryId,
        categoryOrder: item.categoryOrder,
        deviceItemId: item.deviceItemId,
        resetNumber: item.resetNumber,
        cycleNames: item.cycleNames,
        cycleNotes: item.cycleNotes,
        claimedBy: item.claimedBy,
        claimedAt: item.claimedAt,
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
              'count': count.clamp(0, AppConstants.maxCountValue),
              'todaycount': todaycount.clamp(0, AppConstants.maxCountValue),
            };

            // Only include lastResetTime if it's a real value (not 0/epoch)
            if (lastResetTimeSeconds > 0) {
              updateData['lastResetTime'] = lastResetTimeSeconds * 1000;
            }

            // Only include resetNumber if provided
            if (resetNumber != null) {
              updateData['reset_number'] = resetNumber;  // snake_case to match ItemModel.fromFirestore
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
      AppLogger.debug('Datasource: getDeletedItems called for user $userId');
      final userRef = firestore.collection('users').doc(userId);
      AppLogger.debug('Datasource: Querying Firestore...');
      final snapshot = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();
      AppLogger.debug('Datasource: Got ${snapshot.docs.length} total items');

      final deletedItems = snapshot.docs
          .map((doc) => ItemModel.fromFirestore(doc))
          .where((item) => item.deletedAt != null) // Only soft-deleted items
          .toList();
      AppLogger.debug('Datasource: Found ${deletedItems.length} deleted items');
      return deletedItems;
    } on FirebaseException catch (e) {
      AppLogger.debug('Datasource: FirebaseException - ${e.message}');
      throw ServerException('Failed to fetch deleted items: ${e.message}');
    } catch (e) {
      AppLogger.debug('Datasource: Exception - $e');
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

      // Get a new deviceItemId for the restored item (old one may be recycled)
      final newDeviceItemId = await _getNextDeviceItemId(userRef);
      AppLogger.debug('restoreItem: $itemId, new deviceItemId=$newDeviceItemId');

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

      // Restore item with order 0 (top of list), new deviceItemId, and uncategorized
      batch.update(firestore.collection('Item').doc(itemId), {
        'deletedAt': FieldValue.delete(),
        'order': 0,
        'device_item_id': newDeviceItemId,
        'category_id': FieldValue.delete(),  // Uncategorized
        'category_order': 0,
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
        final currentResetNumber = data['reset_number'] as int? ?? 0;
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
          'todaycount': 0,  // lowercase to match ItemModel.fromFirestore
          'reset_number': newResetNumber,  // snake_case to match ItemModel.fromFirestore
          'lastResetTime': nowMillis,
          'lastUpdated': nowMillis,
        });

        // Create reset event log
        // Reset event marks the END of the previous interval (currentResetNumber),
        // not the start of the new one. This allows IntervalCalculator to correctly
        // determine when the old cycle ended and the new cycle began.
        final eventRef = firestore.collection('EventLog').doc();
        final itemDocRef = firestore.collection('Item').doc(doc.id);
        batch.set(eventRef, {
          'created_time': Timestamp.fromDate(now),
          'item': itemDocRef,  // DocumentReference, not string - must match EventLog query
          'event_name': 'reset',
          'increment': 0,
          'currentcount': 0,
          'reset_number': currentResetNumber,  // snake_case to match EventLogModel.fromFirestore
          'user_id': itemUserId,
        });

        // Build updated ItemModel for return — use fromFirestore to capture all
        // fields, then override only the reset-specific ones.
        final resetItem = ItemModel.fromFirestore(doc).copyWith(
          count: 0,
          todayCount: 0,
          resetNumber: newResetNumber,
          lastResetTime: now,
          lastUpdated: now,
        );
        resetItems.add(resetItem);
      }

      await batch.commit();
      return resetItems;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to reset all items: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error resetting all items: $e');
    }
  }

  @override
  Future<void> updateCycleNames(
    String itemId,
    Map<String, String> cycleNames,
  ) async {
    try {
      await firestore.collection('Item').doc(itemId).update({
        'cycle_names': cycleNames,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to update cycle names: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error updating cycle names: $e');
    }
  }

  @override
  Future<void> updateCycleNotes(
    String itemId,
    Map<String, String> cycleNotes,
  ) async {
    try {
      await firestore.collection('Item').doc(itemId).update({
        'cycle_notes': cycleNotes,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to update cycle notes: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error updating cycle notes: $e');
    }
  }

  @override
  Future<int> ensureDeviceItemIds(String userId) async {
    try {
      final userRef = firestore.collection('users').doc(userId);
      final snapshot = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();

      // Find all active items and their existing deviceItemIds
      final activeItems = <DocumentSnapshot<Map<String, dynamic>>>[];
      final usedIds = <int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['deletedAt'] == null) {
          activeItems.add(doc);
          final deviceId = data['device_item_id'] as int?;
          if (deviceId != null) {
            usedIds.add(deviceId);
          }
        }
      }

      // Find items missing deviceItemId
      final itemsNeedingId = activeItems
          .where((doc) => doc.data()?['device_item_id'] == null)
          .toList();

      if (itemsNeedingId.isEmpty) {
        AppLogger.debug('All items have deviceItemId assigned');
        return 0;
      }

      AppLogger.debug('Found ${itemsNeedingId.length} items without deviceItemId');

      // Assign IDs to items that need them
      final batch = firestore.batch();
      int nextId = 0;

      for (final doc in itemsNeedingId) {
        // Find next available ID
        while (usedIds.contains(nextId) && nextId < 100) {
          nextId++;
        }

        if (nextId >= 100) {
          throw ServerException('Maximum 100 items reached');
        }

        final itemName = doc.data()?['item_name'] ?? 'unknown';
        AppLogger.debug('Assigning deviceItemId=$nextId to $itemName');
        batch.update(doc.reference, {'device_item_id': nextId});
        usedIds.add(nextId);
        nextId++;
      }

      await batch.commit();
      AppLogger.debug('Assigned deviceItemId to ${itemsNeedingId.length} items');
      return itemsNeedingId.length;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to ensure device item IDs: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error ensuring device item IDs: $e');
    }
  }

  @override
  Future<void> claimItem(String itemId, String deviceInstanceId) async {
    try {
      await firestore.runTransaction((transaction) async {
        final docRef = firestore.collection('Item').doc(itemId);
        final snapshot = await transaction.get(docRef);
        final data = snapshot.data();
        if (data == null) throw ServerException('Item not found');

        final currentClaim = data['claimed_by'] as String?;
        if (currentClaim == deviceInstanceId) return; // Already owned — no-op
        if (currentClaim != null) {
          throw ClaimConflictException('Item already claimed by $currentClaim');
        }

        transaction.update(docRef, {
          'claimed_by': deviceInstanceId,
          'claimed_at': FieldValue.serverTimestamp(),
        });
      });
    } on ClaimConflictException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to claim item: ${e.message}');
    }
  }

  @override
  Future<void> atomicClaimSwap(String newItemId, String deviceInstanceId, String? previousItemId) async {
    // Query for this device's ACTUAL current claim in Firestore.
    // The previousItemId from BLoC dispatch can be stale after conflicts,
    // so we always use the real Firestore state. Safe because the global
    // claim queue serializes all calls — no concurrent modifications.
    final currentClaimQuery = await firestore.collection('Item')
        .where('claimed_by', isEqualTo: deviceInstanceId)
        .limit(1)
        .get();
    final actualPrevId = currentClaimQuery.docs.isNotEmpty
        ? currentClaimQuery.docs.first.id
        : null;

    try {
      await firestore.runTransaction((transaction) async {
        // Firestore requires ALL reads before ANY writes in a transaction.
        final newRef = firestore.collection('Item').doc(newItemId);
        final newSnapshot = await transaction.get(newRef);

        final hasPrevious = actualPrevId != null && actualPrevId != newItemId;
        DocumentSnapshot? prevSnapshot;
        if (hasPrevious) {
          prevSnapshot = await transaction.get(
            firestore.collection('Item').doc(actualPrevId));
        }

        // Validate new item
        final newData = newSnapshot.data() as Map<String, dynamic>?;
        if (newData == null) throw ServerException('Item not found');

        final currentClaim = newData['claimed_by'] as String?;
        if (currentClaim == deviceInstanceId) return; // Already owned — no-op
        if (currentClaim != null) {
          throw ClaimConflictException('Item already claimed by $currentClaim');
        }

        // Release previous item only if we still own it
        if (hasPrevious && prevSnapshot != null) {
          final prevData = prevSnapshot.data() as Map<String, dynamic>?;
          if (prevData != null && prevData['claimed_by'] == deviceInstanceId) {
            transaction.update(prevSnapshot.reference, {
              'claimed_by': null,
              'claimed_at': null,
            });
          }
        }

        // Claim new item
        transaction.update(newRef, {
          'claimed_by': deviceInstanceId,
          'claimed_at': FieldValue.serverTimestamp(),
        });
      });
    } on ClaimConflictException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to claim item: ${e.message}');
    }
  }

  @override
  Future<void> releaseItem(String itemId) async {
    try {
      await firestore.collection('Item').doc(itemId).update({
        'claimed_by': null,
        'claimed_at': null,
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to release item: ${e.message}');
    }
  }

  @override
  Future<void> releaseAllClaims(String deviceInstanceId, String userId) async {
    try {
      final userRef = firestore.collection('users').doc(userId);
      final querySnapshot = await firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .where('claimed_by', isEqualTo: deviceInstanceId)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'claimed_by': FieldValue.delete(),
          'claimed_at': FieldValue.delete(),
        });
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to release all claims: ${e.message}');
    }
  }
}
