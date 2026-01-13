import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/event_log.dart';
import '../../domain/repositories/event_log_repository.dart';
import '../datasources/event_log_remote_datasource.dart';
import '../models/event_log_model.dart';

/// Implementation of EventLogRepository that delegates to EventLogRemoteDataSource.
///
/// This class sits between the domain layer (use cases) and the data layer
/// (data sources). It converts domain entities to data models and vice versa,
/// and converts exceptions thrown by the data source into Failure objects
/// wrapped in Either.
///
/// Uses FirebaseAuth to get the current user ID for queries that require it.
///
/// Error handling flow:
/// 1. Data source throws ServerException
/// 2. Repository catches exception
/// 3. Repository returns Left(ServerFailure(...))
/// 4. Use cases receive Either<Failure, T>
/// 5. BLoC handles success/failure with fold()
@LazySingleton(as: EventLogRepository)
class EventLogRepositoryImpl implements EventLogRepository {
  final EventLogRemoteDataSource remoteDataSource;
  final FirebaseAuth firebaseAuth;

  EventLogRepositoryImpl(this.remoteDataSource, this.firebaseAuth);

  @override
  Future<Either<Failure, List<EventLog>>> getEventsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final userId = firebaseAuth.currentUser?.uid;
      if (userId == null) {
        return const Left(AuthFailure('User not authenticated'));
      }

      final events = await remoteDataSource.getEventsByDateRange(
        userId,
        startDate,
        endDate,
      );
      return Right(events);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> insertEvents(List<EventLog> events) async {
    try {
      if (events.isEmpty) {
        return const Right(null);
      }

      final eventModels = events
          .map((event) => EventLogModel.fromEntity(event))
          .toList();

      await remoteDataSource.insertEventsBatch(eventModels);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<EventLog>>> getEventsByItem(String itemId) async {
    try {
      final events = await remoteDataSource.getEventsByItem(itemId);
      return Right(events);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEventsForItem(String itemId) async {
    try {
      await remoteDataSource.deleteEventsForItem(itemId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
