import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/event_log.dart';
import '../repositories/event_log_repository.dart';

/// Parameters for GetEventsByItemUseCase.
///
/// Contains the item ID to fetch events for.
class GetEventsByItemParams extends Equatable {
  final String itemId;

  const GetEventsByItemParams(this.itemId);

  @override
  List<Object> get props => [itemId];
}

/// Use case for fetching all events for a specific item.
///
/// Used for viewing item history and detailed analytics.
/// Returns events ordered by createdTime descending.
///
/// Example:
/// ```dart
/// final result = await getEventsByItemUseCase(
///   GetEventsByItemParams('item_123'),
/// );
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (events) => print('Found ${events.length} events for item'),
/// );
/// ```
@lazySingleton
class GetEventsByItemUseCase
    extends UseCase<List<EventLog>, GetEventsByItemParams> {
  final EventLogRepository repository;

  GetEventsByItemUseCase(this.repository);

  @override
  Future<Either<Failure, List<EventLog>>> call(
    GetEventsByItemParams params,
  ) async {
    return await repository.getEventsByItem(params.itemId);
  }
}
