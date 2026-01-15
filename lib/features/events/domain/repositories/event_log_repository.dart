import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/event_log.dart';

/// Repository interface for EventLog operations.
///
/// Defines the contract for event log data access. The data layer will implement
/// this interface to provide concrete implementations using Firebase Firestore.
///
/// All methods return Either<Failure, T> for type-safe error handling.
/// - Left(Failure): Operation failed
/// - Right(T): Operation succeeded with result
///
/// Following clean architecture, the domain layer defines the interface,
/// and the data layer provides the implementation.
abstract class EventLogRepository {
  /// Fetches events within a date range for the current user.
  ///
  /// Used for charting and analytics. Events are ordered by createdTime descending.
  ///
  /// Parameters:
  /// - [startDate]: Start of date range (inclusive)
  /// - [endDate]: End of date range (inclusive)
  ///
  /// Returns:
  /// - Right(List<EventLog>): List of events in range (empty list if none)
  /// - Left(ServerFailure): Firestore query failed
  /// - Left(AuthFailure): User not authenticated
  Future<Either<Failure, List<EventLog>>> getEventsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  /// Inserts multiple events in a batch operation.
  ///
  /// Used when receiving events from ESP32 device via Bluetooth.
  /// Batch inserts improve performance when multiple events arrive together.
  ///
  /// Note: 'switch' events should not be stored - they only update Item.lastUpdated.
  /// Filter out switch events before calling this method.
  ///
  /// Returns:
  /// - Right(void): Events successfully inserted
  /// - Left(ServerFailure): Firestore batch write failed
  Future<Either<Failure, void>> insertEvents(List<EventLog> events);

  /// Fetches all events for a specific item.
  ///
  /// Used for viewing item history and detailed analytics.
  /// Events are ordered by createdTime descending.
  ///
  /// Parameters:
  /// - [itemId]: ID of the item to fetch events for
  ///
  /// Returns:
  /// - Right(List<EventLog>): List of events for the item (empty list if none)
  /// - Left(ServerFailure): Firestore query failed
  Future<Either<Failure, List<EventLog>>> getEventsByItem(String itemId);

  /// Fetches events for a specific item within a date range.
  ///
  /// Used for charting and analytics filtered by item.
  /// Events are ordered by createdTime ascending for chart display.
  ///
  /// Parameters:
  /// - [itemId]: ID of the item to fetch events for
  /// - [startDate]: Start of date range (inclusive)
  /// - [endDate]: End of date range (inclusive)
  ///
  /// Returns:
  /// - Right(List<EventLog>): List of events in range (empty list if none)
  /// - Left(ServerFailure): Firestore query failed
  Future<Either<Failure, List<EventLog>>> getEventsByItemAndDateRange(
    String itemId,
    DateTime startDate,
    DateTime endDate,
  );

  /// Deletes all events for a specific item.
  ///
  /// Called when an item is deleted to clean up associated event logs.
  /// Uses batch delete for efficiency.
  ///
  /// Parameters:
  /// - [itemId]: ID of the item whose events should be deleted
  ///
  /// Returns:
  /// - Right(void): Events successfully deleted
  /// - Left(ServerFailure): Firestore batch delete failed
  Future<Either<Failure, void>> deleteEventsForItem(String itemId);
}
