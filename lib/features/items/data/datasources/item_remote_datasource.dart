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
  /// Sets initial count and todayCount to 0, and timestamps to current time.
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
}
