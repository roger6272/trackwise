import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/validators.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Parameters for [UpdateCategoryUseCase].
class UpdateCategoryParams extends Equatable {
  final Category category;

  const UpdateCategoryParams(this.category);

  @override
  List<Object> get props => [category];
}

/// Use case for updating an existing category.
///
/// Validates:
/// - Name is not empty
/// - Name is max 30 characters
/// - Name is unique (excluding the current category)
@lazySingleton
class UpdateCategoryUseCase extends UseCase<Category, UpdateCategoryParams> {
  final CategoryRepository repository;

  UpdateCategoryUseCase(this.repository);

  @override
  Future<Either<Failure, Category>> call(UpdateCategoryParams params) async {
    final category = params.category;

    // Validate name
    final nameError = Validators.validateCategoryName(category.name);
    if (nameError != null) {
      return Left(ValidationFailure(nameError));
    }

    // Check for duplicate name (excluding self)
    final existsResult = await repository.categoryNameExists(
      category.userId,
      category.name,
      excludeId: category.id,
    );

    // Handle failure case
    if (existsResult.isLeft()) {
      return Left(existsResult.fold((f) => f, (_) => const ServerFailure('')));
    }

    // Check if name already exists
    final exists = existsResult.getOrElse(() => false);
    if (exists) {
      return const Left(ValidationFailure(
        'A category with this name already exists',
      ));
    }

    return repository.updateCategory(category);
  }
}
