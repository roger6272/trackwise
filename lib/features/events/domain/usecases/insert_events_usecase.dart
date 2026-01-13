import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/event_log.dart';
import '../repositories/event_log_repository.dart';

/// Parameters for InsertEventsUseCase.
///
/// Contains the list of events to insert.
class InsertEventsParams extends Equatable {
  final List<EventLog> events;

  const InsertEventsParams(this.events);

  @override
  List<Object> get props => [events];
}

/// Use case for inserting multiple events in a batch.
///
/// Used when receiving events from ESP32 device via Bluetooth.
/// Batch inserts improve performance when multiple events arrive together.
///
/// Note: 'switch' events should be filtered out before calling this use case.
/// Switch events only update Item.lastUpdated and are not stored in EventLog.
///
/// Example:
/// ```dart
/// final events = [
///   EventLog(id: '1', eventName: 'increment', ...),
///   EventLog(id: '2', eventName: 'increment', ...),
/// ];
/// final result = await insertEventsUseCase(InsertEventsParams(events));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (_) => print('Events inserted successfully'),
/// );
/// ```
@lazySingleton
class InsertEventsUseCase extends UseCase<void, InsertEventsParams> {
  final EventLogRepository repository;

  InsertEventsUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(InsertEventsParams params) async {
    // Filter out 'switch' events - they don't create EventLog entries
    final eventsToInsert = params.events
        .where((event) => event.eventName != 'switch')
        .toList();

    if (eventsToInsert.isEmpty) {
      return const Right(null);
    }

    return await repository.insertEvents(eventsToInsert);
  }
}
