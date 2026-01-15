import '../../../../core/error/exceptions.dart';
import '../models/event_log_model.dart';

/// Abstract interface for EventLog remote data operations.
///
/// Defines Firestore operations for the EventLog feature. All methods throw
/// [ServerException] on failure rather than returning Either types.
/// The repository layer will catch these exceptions and convert them to Failures.
///
/// This interface allows for easy testing by mocking the data source,
/// and follows the dependency inversion principle by not depending on
/// concrete Firestore implementations.
abstract class EventLogRemoteDataSource {
  /// Fetches events within a date range for a user from Firestore.
  ///
  /// Queries the EventLog collection filtered by user_id and createdTime.
  /// Results are ordered by createdTime descending.
  ///
  /// Parameters:
  /// - [userId]: Firebase UID of the user
  /// - [startDate]: Start of date range (inclusive)
  /// - [endDate]: End of date range (inclusive)
  ///
  /// Returns a list of EventLogModel objects.
  ///
  /// Throws [ServerException] if the Firestore operation fails.
  Future<List<EventLogModel>> getEventsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );

  /// Inserts multiple events in a batch operation.
  ///
  /// Uses Firestore batch writes for atomic insertion of multiple events.
  /// Each event's ID is used as the document ID.
  ///
  /// Parameters:
  /// - [events]: List of EventLogModel objects to insert
  ///
  /// Throws [ServerException] if the Firestore batch write fails.
  Future<void> insertEventsBatch(List<EventLogModel> events);

  /// Fetches all events for a specific item from Firestore.
  ///
  /// Queries the EventLog collection filtered by item_id.
  /// Results are ordered by createdTime descending.
  ///
  /// Parameters:
  /// - [itemId]: ID of the item to fetch events for
  ///
  /// Returns a list of EventLogModel objects.
  ///
  /// Throws [ServerException] if the Firestore operation fails.
  Future<List<EventLogModel>> getEventsByItem(String itemId);

  /// Fetches events for a specific item within a date range from Firestore.
  ///
  /// Queries the EventLog collection filtered by item_id and created_time.
  /// Results are ordered by createdTime ascending for chart display.
  ///
  /// Parameters:
  /// - [itemId]: ID of the item to fetch events for
  /// - [startDate]: Start of date range (inclusive)
  /// - [endDate]: End of date range (inclusive)
  ///
  /// Returns a list of EventLogModel objects.
  ///
  /// Throws [ServerException] if the Firestore operation fails.
  Future<List<EventLogModel>> getEventsByItemAndDateRange(
    String itemId,
    DateTime startDate,
    DateTime endDate,
  );

  /// Deletes all events for a specific item from Firestore.
  ///
  /// Uses Firestore batch writes for atomic deletion of multiple documents.
  ///
  /// Parameters:
  /// - [itemId]: ID of the item whose events should be deleted
  ///
  /// Throws [ServerException] if the Firestore batch delete fails.
  Future<void> deleteEventsForItem(String itemId);
}
