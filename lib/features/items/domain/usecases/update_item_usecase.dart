import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/validators.dart';
import '../entities/item.dart';
import '../repositories/item_repository.dart';

/// Parameters for UpdateItemUseCase.
///
/// Contains the full item with updates applied.
class UpdateItemParams extends Equatable {
  /// The item to update (with all fields including changes)
  final Item item;

  const UpdateItemParams(this.item);

  @override
  List<Object> get props => [item];
}

/// Use case for updating an existing item.
///
/// Validates the item data before delegating to the repository.
/// Returns ValidationFailure if validation fails.
///
/// Validation rules:
/// - Name: Required, max 30 characters
/// - IncrementBy: 1-100 range
/// - ReminderValue: 0-1000 range
///
/// The repository will update the lastUpdated timestamp.
///
/// Example:
/// ```dart
/// final updatedItem = existingItem.copyWith(
///   name: 'New Name',
///   incrementBy: 5,
/// );
/// final result = await updateItemUseCase(UpdateItemParams(updatedItem));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (item) => print('Updated: ${item.name}'),
/// );
/// ```
@lazySingleton
class UpdateItemUseCase extends UseCase<Item, UpdateItemParams> {
  final ItemRepository repository;

  UpdateItemUseCase(this.repository);

  @override
  Future<Either<Failure, Item>> call(UpdateItemParams params) async {
    final item = params.item;

    // Validate item name
    final nameError = Validators.validateItemName(item.name);
    if (nameError != null) {
      return Left(ValidationFailure(nameError));
    }

    // Validate increment value
    final incrementError = Validators.validateIncrementValue(item.incrementBy);
    if (incrementError != null) {
      return Left(ValidationFailure(incrementError));
    }

    // Validate reminder value
    final reminderError = Validators.validateReminderValue(item.reminderValue);
    if (reminderError != null) {
      return Left(ValidationFailure(reminderError));
    }

    // All validation passed, update the item
    // The repository will update the lastUpdated timestamp
    return await repository.updateItem(item);
  }
}
