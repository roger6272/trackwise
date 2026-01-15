import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../models/event_log_model.dart';
import 'event_log_remote_datasource.dart';

/// Concrete implementation of EventLogRemoteDataSource using Firestore.
///
/// Handles all Firestore operations for the EventLog feature. Converts Firestore
/// documents to EventLogModel objects and vice versa. All methods throw
/// [ServerException] on failure.
///
/// Uses Injectable for dependency injection with FirebaseFirestore instance.
///
/// Firestore schema notes:
/// - `uid` field is a DocumentReference to /users/{userId}
/// - `item` field is a DocumentReference to /Item/{itemId}
/// - `created_time` field is a Timestamp
///
/// Required Firestore composite index:
/// - Collection: EventLog
/// - Fields: uid (ascending), created_time (descending)
@LazySingleton(as: EventLogRemoteDataSource)
class EventLogRemoteDataSourceImpl implements EventLogRemoteDataSource {
  final FirebaseFirestore firestore;

  EventLogRemoteDataSourceImpl(this.firestore);

  @override
  Future<List<EventLogModel>> getEventsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Query using DocumentReference for uid field
      final userRef = firestore.doc('/users/$userId');

      final snapshot = await firestore
          .collection('EventLog')
          .where('uid', isEqualTo: userRef)
          .where(
            'created_time',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where(
            'created_time',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
          )
          .orderBy('created_time', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => EventLogModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to fetch events by date range: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error fetching events: $e');
    }
  }

  @override
  Future<void> insertEventsBatch(List<EventLogModel> events) async {
    if (events.isEmpty) return;

    try {
      final batch = firestore.batch();

      for (final event in events) {
        final docRef = firestore.collection('EventLog').doc(event.id);
        batch.set(docRef, event.toFirestore(firestore), SetOptions(merge: true));
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to insert events batch: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error inserting events: $e');
    }
  }

  @override
  Future<List<EventLogModel>> getEventsByItem(String itemId) async {
    try {
      // Query using DocumentReference for item field
      final itemRef = firestore.doc('/Item/$itemId');

      // Note: Not using orderBy in Firestore to avoid requiring composite index.
      // Sorting in memory instead for simpler setup.
      final snapshot = await firestore
          .collection('EventLog')
          .where('item', isEqualTo: itemRef)
          .get();

      final events = snapshot.docs
          .map((doc) => EventLogModel.fromFirestore(doc))
          .toList();

      // Sort in memory by created_time descending
      events.sort((a, b) => b.createdTime.compareTo(a.createdTime));

      return events;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to fetch events for item: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error fetching events for item: $e');
    }
  }

  @override
  Future<List<EventLogModel>> getEventsByItemAndDateRange(
    String itemId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Query using DocumentReference for item field
      final itemRef = firestore.doc('/Item/$itemId');

      final snapshot = await firestore
          .collection('EventLog')
          .where('item', isEqualTo: itemRef)
          .where(
            'created_time',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .orderBy('created_time', descending: false)
          .get();

      final events = snapshot.docs
          .map((doc) => EventLogModel.fromFirestore(doc))
          .toList();

      return events;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to fetch events for item by date range: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error fetching events for item by date range: $e');
    }
  }

  @override
  Future<void> deleteEventsForItem(String itemId) async {
    try {
      // Query using DocumentReference for item field
      final itemRef = firestore.doc('/Item/$itemId');

      final snapshot = await firestore
          .collection('EventLog')
          .where('item', isEqualTo: itemRef)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to delete events for item: ${e.message}');
    } catch (e) {
      throw ServerException('Unexpected error deleting events: $e');
    }
  }
}
