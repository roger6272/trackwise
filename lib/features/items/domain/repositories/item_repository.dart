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
}
