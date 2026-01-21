import '../../../../core/error/exceptions.dart';
import '../models/item_model.dart';

/// Abstract interface for Item remote data operations.
///
/// Defines Firestore operations for the Item feature. All methods throw
/// [ServerException] on failure rather than returning Either types.
/// The repository layer will catch these exceptions and convert them to Failures.
///
/// This interface allows for easy testing by mocking the data source,
/// and follows the dependency inversion principle by not depending on
/// concrete Firestore implementations.
abstract class ItemRemoteDataSource {
  /// Fetches all items for a user from Firestore.
  ///
  /// Queries the Item collection filtered by user_id.
  ///
  /// Returns a list of ItemModel objects.
  ///
  /// Throws [ServerException] if the Firestore operation fails.
  Future<List<ItemModel>> getItems(String userId);

  /// Fetches a single item by ID from Firestore.
  ///
  /// Returns the ItemModel if found.
  ///
  /// Throws [ServerException] if:
  /// - The Firestore operation fails
  /// - The item document doesn't exist
  Future<ItemModel> getItem(String itemId);

  /// Watches items for a user with real-time updates.
  ///
  /// Returns a Stream that emits a list of items whenever the Firestore
  /// collection changes. The stream filters items by user_id.
  ///
  /// The stream will emit errors as [ServerException] via handleError.
  ///
  /// Example:
  /// ```dart
  /// dataSource.watchItems('user_123').listen((items) {
  ///   print('Items updated: ${items.length}');
  /// }, onError: (error) {
  ///   if (error is ServerException) {
  ///     print('Error: ${error.message}');
  ///   }
  /// });
  /// ```
  Stream<List<ItemModel>> watchItems(String userId);

  /// Creates a new item in Firestore.
  ///
  /// If the item's ID is empty, generates a new Firestore document ID.
  /// Uses the count and todayCount from the provided item (for initial value support).
  /// Sets lastUpdated to current time.
  ///
  /// Returns the created ItemModel with the generated ID and timestamps.
  ///
  /// Throws [ServerException] if the Firestore operation fails.
  Future<ItemModel> createItem(ItemModel item);

  /// Updates an existing item in Firestore.
  ///
  /// Updates the lastUpdated timestamp to the current time.
  /// All other fields are taken from the provided item.
  ///
  /// Returns the updated ItemModel with the new lastUpdated timestamp.
  ///
  /// Throws [ServerException] if the Firestore operation fails.
  Future<ItemModel> updateItem(ItemModel item);

  /// Deletes an item and its associated EventLog entries from Firestore.
  ///
  /// This operation:
  /// 1. Deletes the Item document
  /// 2. Queries and deletes all EventLog documents where item_id matches
  ///
  /// Uses Firestore batch writes for the EventLog deletion to ensure
  /// atomicity.
  ///
  /// Throws [ServerException] if any Firestore operation fails.
  Future<void> deleteItem(String itemId);

  /// Increments an item's count and todayCount by the specified amount.
  ///
  /// Fetches the current item, adds the amount to both count and todayCount,
  /// updates lastUpdated to current time, and writes back to Firestore.
  ///
  /// Returns the updated ItemModel.
  ///
  /// Throws [ServerException] if:
  /// - The item doesn't exist
  /// - Any Firestore operation fails
  Future<ItemModel> incrementItem(String itemId, int amount);

  /// Resets the daily count (todayCount) for an item to 0.
  ///
  /// Also updates lastResetTime and lastUpdated to the current time.
  ///
  /// This is typically called at midnight or when the user manually resets
  /// the daily count.
  ///
  /// Throws [ServerException] if the Firestore operation fails.
  Future<void> resetDailyCount(String itemId);

  /// Batch updates item counts from ESP32 device data.
  ///
  /// Used when receiving 'prefs' message from device. Only updates items
  /// that exist in Firestore for the given user.
  ///
  /// Parameters:
  /// - [userId]: User ID to filter items
  /// - [itemData]: List of maps with {id, count, todaycount, lastResetTime}
  ///
  /// Throws [ServerException] if the Firestore batch operation fails.
  Future<void> batchUpdateCounts(
    String userId,
    List<Map<String, dynamic>> itemData,
  );

  /// Fetches all soft-deleted items for a user from Firestore.
  ///
  /// Queries the Item collection filtered by user_id where deletedAt is not null.
  /// These items are within the 90-day retention period.
  ///
  /// Returns a list of ItemModel objects.
  ///
  /// Throws [ServerException] if the Firestore operation fails.
  Future<List<ItemModel>> getDeletedItems(String userId);

  /// Restores a soft-deleted item by clearing the deletedAt field.
  ///
  /// Sets deletedAt to null so the item appears in normal queries again.
  ///
  /// Throws [ServerException] if the Firestore operation fails.
  Future<void> restoreItem(String itemId);

  /// Updates the order field for multiple items in a batch.
  ///
  /// Used for drag-to-reorder functionality. Each item's order field is set
  /// to its index in the provided list.
  ///
  /// Parameters:
  /// - [items]: List of items with their new order values already set
  ///
  /// Throws [ServerException] if the Firestore batch operation fails.
  Future<void> reorderItems(List<ItemModel> items);

  /// Updates the categoryOrder field for multiple items in a batch.
  ///
  /// Used for drag-to-reorder when viewing a specific category.
  /// Each item's categoryOrder field is set to its index in the provided list.
  ///
  /// Parameters:
  /// - [items]: List of items with their new categoryOrder values already set
  ///
  /// Throws [ServerException] if the Firestore batch operation fails.
  Future<void> reorderItemsInCategory(List<ItemModel> items);

  /// Moves an item to a different category.
  ///
  /// Updates the item's category_id and sets category_order to max+1
  /// for the new category.
  ///
  /// Parameters:
  /// - [itemId]: The item to move
  /// - [newCategoryId]: The target category (null for uncategorized)
  /// - [newCategoryOrder]: The new categoryOrder value for the item
  ///
  /// Throws [ServerException] if the Firestore update fails.
  Future<void> moveItemToCategory(
    String itemId,
    String? newCategoryId,
    int newCategoryOrder,
  );

  /// Gets the maximum categoryOrder value for items in a category.
  ///
  /// Parameters:
  /// - [userId]: The user's items to check
  /// - [categoryId]: The category to check (null for uncategorized)
  ///
  /// Returns the maximum categoryOrder value (0 if no items).
  ///
  /// Throws [ServerException] if the Firestore query fails.
  Future<int> getMaxCategoryOrder(String userId, String? categoryId);
}
