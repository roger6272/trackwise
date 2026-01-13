import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/event_log.dart';
import '../repositories/event_log_repository.dart';

/// Parameters for GetEventsByDateRangeUseCase.
///
/// Contains the date range to query events within.
class GetEventsByDateRangeParams extends Equatable {
  final DateTime startDate;
  final DateTime endDate;

  const GetEventsByDateRangeParams({
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object> get props => [startDate, endDate];
}

/// Use case for fetching events within a date range.
///
/// Used for charting and analytics features. Returns events ordered
/// by createdTime descending.
///
/// Example:
/// ```dart
/// final result = await getEventsByDateRangeUseCase(
///   GetEventsByDateRangeParams(
///     startDate: DateTime(2024, 1, 1),
///     endDate: DateTime(2024, 1, 31),
///   ),
/// );
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (events) => print('Found ${events.length} events'),
/// );
/// ```
@lazySingleton
class GetEventsByDateRangeUseCase
    extends UseCase<List<EventLog>, GetEventsByDateRangeParams> {
  final EventLogRepository repository;

  GetEventsByDateRangeUseCase(this.repository);

  @override
  Future<Either<Failure, List<EventLog>>> call(
    GetEventsByDateRangeParams params,
  ) async {
    return await repository.getEventsByDateRange(
      params.startDate,
      params.endDate,
    );
  }
}
