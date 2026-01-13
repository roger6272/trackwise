import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/event_log_repository.dart';

/// Parameters for DeleteEventsForItemUseCase.
///
/// Contains the item ID whose events should be deleted.
class DeleteEventsForItemParams extends Equatable {
  final String itemId;

  const DeleteEventsForItemParams(this.itemId);

  @override
  List<Object> get props => [itemId];
}

/// Use case for deleting all events associated with an item.
///
/// Called when an item is deleted to clean up associated event logs.
/// Uses batch delete for efficiency.
///
/// Example:
/// ```dart
/// final result = await deleteEventsForItemUseCase(
///   DeleteEventsForItemParams('item_123'),
/// );
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (_) => print('Events deleted successfully'),
/// );
/// ```
@lazySingleton
class DeleteEventsForItemUseCase
    extends UseCase<void, DeleteEventsForItemParams> {
  final EventLogRepository repository;

  DeleteEventsForItemUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteEventsForItemParams params) async {
    return await repository.deleteEventsForItem(params.itemId);
  }
}
