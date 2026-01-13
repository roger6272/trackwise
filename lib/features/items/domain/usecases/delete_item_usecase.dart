import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/item_repository.dart';

/// Parameters for DeleteItemUseCase.
///
/// Contains the item ID to delete.
class DeleteItemParams extends Equatable {
  /// The ID of the item to delete
  final String itemId;

  const DeleteItemParams(this.itemId);

  @override
  List<Object> get props => [itemId];
}

/// Use case for deleting an item permanently.
///
/// This is a simple pass-through use case that delegates to the repository.
/// The repository will also delete associated EventLog entries.
///
/// Warning: This operation is permanent and cannot be undone.
///
/// Example:
/// ```dart
/// final result = await deleteItemUseCase(DeleteItemParams('item_123'));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (_) => print('Item deleted successfully'),
/// );
/// ```
@lazySingleton
class DeleteItemUseCase extends UseCase<void, DeleteItemParams> {
  final ItemRepository repository;

  DeleteItemUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteItemParams params) async {
    return await repository.deleteItem(params.itemId);
  }
}
