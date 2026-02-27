import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/item.dart';

/// Repository interface for Item operations.
///
/// Defines the contract for item data access. The data layer will implement
/// this interface to provide concrete implementations using Firebase Firestore.
///
/// All methods return Either<Failure, T> for type-safe error handling.
/// - Left(Failure): Operation failed
/// - Right(T): Operation succeeded with result
///
/// Following clean architecture, the domain layer defines the interface,
/// and the data layer provides the implementation.
abstract class ItemRepository {
  /// Fetches all items for a specific user (one-time query).
  ///
  /// Returns:
  /// - Right(List<Item>): List of user's items (empty list if none)
  /// - Left(ServerFailure): Firestore query failed
  /// - Left(AuthFailure): User not authenticated
  Future<Either<Failure, List<Item>>> getItems(String userId);

  /// Fetches a single item by ID.
  ///
  /// Returns:
  /// - Right(Item): Item found
  /// - Left(ServerFailure): Firestore query failed or item not found
  Future<Either<Failure, Item>> getItem(String itemId);

  /// Watches a single item for real-time updates.
  ///
  /// Returns a stream that emits Either for each Firestore snapshot:
  /// - Right(Item): Updated item
  /// - Left(ServerFailure): Firestore stream error or item not found
  ///
  /// Use this for real-time UI updates on item detail screens.
  Stream<Either<Failure, Item>> watchItem(String itemId);

  /// Watches items for a user with real-time updates.
  ///
  /// Returns a stream that emits Either for each Firestore snapshot:
  /// - Right(List<Item>): Updated list of items
  /// - Left(ServerFailure): Firestore stream error
  ///
  /// Use this for real-time UI updates (e.g., items list screen).
  Stream<Either<Failure, List<Item>>> watchItems(String userId);

  /// Creates a new item.
  ///
  /// The item's id should be generated (e.g., UUID or Firestore auto-ID).
  /// Timestamps (lastResetTime, lastUpdated) should be set to current time.
  /// Initial counts (count, todayCount) should be 0.
  ///
  /// Returns:
  /// - Right(Item): Created item with generated ID and timestamps
  /// - Left(ServerFailure): Firestore create operation failed
  /// - Left(ValidationFailure): Item data invalid (should be validated in use case)
  Future<Either<Failure, Item>> createItem(Item item);

  /// Updates an existing item.
  ///
  /// Updates the item document in Firestore. The lastUpdated timestamp
  /// should be updated to the current time.
  ///
  /// Returns:
  /// - Right(Item): Updated item
  /// - Left(ServerFailure): Firestore update operation failed or item not found
  /// - Left(ValidationFailure): Item data invalid (should be validated in use case)
  Future<Either<Failure, Item>> updateItem(Item item);

  /// Deletes an item permanently.
  ///
  /// Also deletes associated EventLog entries where itemId matches.
  ///
  /// Returns:
  /// - Right(void): Item successfully deleted
  /// - Left(ServerFailure): Firestore delete operation failed
  Future<Either<Failure, void>> deleteItem(String itemId);

  /// Increments an item's count.
  ///
  /// Adds the specified amount to both count and todayCount.
  /// Updates lastUpdated timestamp.
  /// Creates an EventLog entry for the increment.
  ///
  /// This is used when incrementing from the app UI (not just Bluetooth events).
  ///
  /// Returns:
  /// - Right(Item): Updated item with new counts
  /// - Left(ServerFailure): Firestore update operation failed
  Future<Either<Failure, Item>> incrementItem(String itemId, int amount);

  /// Resets the daily count for an item.
  ///
  /// Sets todayCount to 0 and updates lastResetTime to current time.
  /// Used by ESP32 device at midnight for automatic daily reset.
  ///
  /// Returns:
  /// - Right(void): Daily count successfully reset
  /// - Left(ServerFailure): Firestore update operation failed
  Future<Either<Failure, void>> resetDailyCount(String itemId);

  /// Batch updates item counts from ESP32 device data.
  ///
  /// Used when receiving 'prefs' message from device containing current
  /// counts for all items. Only updates items that exist in Firestore.
  ///
  /// Parameters:
  /// - [userId]: User ID to filter items
  /// - [itemData]: List of maps containing {id, count, todaycount, lastResetTime}
  ///
  /// Returns:
  /// - Right(void): Items successfully updated
  /// - Left(ServerFailure): Firestore batch update failed
  Future<Either<Failure, void>> batchUpdateCounts(
    String userId,
    List<Map<String, dynamic>> itemData,
  );

  /// Fetches all soft-deleted items for a user.
  ///
  /// Returns items where deletedAt is not null (within 30-day retention).
  ///
  /// Returns:
  /// - Right(List<Item>): List of soft-deleted items
  /// - Left(ServerFailure): Firestore query failed
  Future<Either<Failure, List<Item>>> getDeletedItems(String userId);

  /// Restores a soft-deleted item.
  ///
  /// Clears the deletedAt field so the item appears in normal queries.
  ///
  /// Returns:
  /// - Right(void): Item successfully restored
  /// - Left(ServerFailure): Firestore update failed
  Future<Either<Failure, void>> restoreItem(String itemId);

  /// Reorders items by updating their order field in batch.
  ///
  /// Used for drag-to-reorder functionality. Each item's order field is set
  /// to its index in the provided list.
  ///
  /// Parameters:
  /// - [items]: List of items in their new order
  ///
  /// Returns:
  /// - Right(void): Items successfully reordered
  /// - Left(ServerFailure): Firestore batch update failed
  Future<Either<Failure, void>> reorderItems(List<Item> items);

  /// Reorders items within a category by updating their categoryOrder field.
  ///
  /// Used for drag-to-reorder when viewing a specific category.
  /// Each item's categoryOrder field is set to its index in the provided list.
  ///
  /// Parameters:
  /// - [items]: List of items in their new order within the category
  ///
  /// Returns:
  /// - Right(void): Items successfully reordered
  /// - Left(ServerFailure): Firestore batch update failed
  Future<Either<Failure, void>> reorderItemsInCategory(List<Item> items);

  /// Moves an item to a different category.
  ///
  /// Updates the item's categoryId and sets categoryOrder to max+1
  /// for the new category. If newCategoryId is null, the item becomes
  /// uncategorized.
  ///
  /// Parameters:
  /// - [itemId]: The item to move
  /// - [newCategoryId]: The target category (null for uncategorized)
  ///
  /// Returns:
  /// - Right(void): Item successfully moved
  /// - Left(ServerFailure): Firestore update failed
  Future<Either<Failure, void>> moveItemToCategory(
    String itemId,
    String? newCategoryId,
  );

  /// Gets the maximum categoryOrder value for items in a category.
  ///
  /// Used to calculate the next categoryOrder when adding/moving items.
  ///
  /// Parameters:
  /// - [userId]: The user's items to check
  /// - [categoryId]: The category to check (null for uncategorized)
  ///
  /// Returns:
  /// - Right(int): The maximum categoryOrder value (0 if no items)
  /// - Left(ServerFailure): Firestore query failed
  Future<Either<Failure, int>> getMaxCategoryOrder(
    String userId,
    String? categoryId,
  );

  /// Resets all items to start a new cycle.
  ///
  /// For each item:
  /// - count is set to 0
  /// - todayCount is set to 0
  /// - resetNumber is incremented by 1
  /// - lastResetTime is set to current time
  /// - lastUpdated is set to current time
  ///
  /// Also creates a 'reset' event log for each item.
  ///
  /// Parameters:
  /// - [userId]: The user whose items to reset
  ///
  /// Returns:
  /// - Right(List<Item>): List of reset items
  /// - Left(ServerFailure): Firestore batch update failed
  Future<Either<Failure, List<Item>>> resetAllItems(String userId);

  /// Updates the cycle names for an item.
  ///
  /// Performs a targeted Firestore update (only the cycle_names field),
  /// avoiding full document validation.
  ///
  /// Parameters:
  /// - [itemId]: The item to update
  /// - [cycleNames]: Map of resetNumber (as string) to custom name
  ///
  /// Returns:
  /// - Right(void): Cycle names successfully updated
  /// - Left(ServerFailure): Firestore update failed
  Future<Either<Failure, void>> updateCycleNames(
    String itemId,
    Map<String, String> cycleNames,
  );

  /// Updates the cycle notes for an item.
  ///
  /// Performs a targeted Firestore update (only the cycle_notes field),
  /// avoiding full document validation.
  ///
  /// Parameters:
  /// - [itemId]: The item to update
  /// - [cycleNotes]: Map of resetNumber (as string) to note text
  ///
  /// Returns:
  /// - Right(void): Cycle notes successfully updated
  /// - Left(ServerFailure): Firestore update failed
  Future<Either<Failure, void>> updateCycleNotes(
    String itemId,
    Map<String, String> cycleNotes,
  );

  /// Ensures all items have a valid deviceItemId assigned.
  ///
  /// Migrates items that were created before deviceItemId was implemented.
  /// Each item without a deviceItemId is assigned a unique ID (0-99).
  ///
  /// Parameters:
  /// - [userId]: The user whose items to check and fix
  ///
  /// Returns:
  /// - Right(int): Number of items that were assigned new deviceItemIds
  /// - Left(ServerFailure): Firestore operations failed
  Future<Either<Failure, int>> ensureDeviceItemIds(String userId);

  /// Claims an item for exclusive use by a device.
  Future<Either<Failure, void>> claimItem(String itemId, String deviceInstanceId);

  /// Atomically releases [previousItemId] and claims [newItemId] for [deviceInstanceId]
  /// in a single Firestore transaction.
  Future<Either<Failure, void>> atomicClaimSwap(String newItemId, String deviceInstanceId, String? previousItemId);

  /// Releases a claim on an item.
  Future<Either<Failure, void>> releaseItem(String itemId);

  /// Releases all claims by a specific device.
  Future<Either<Failure, void>> releaseAllClaims(String deviceInstanceId, String userId);
}
