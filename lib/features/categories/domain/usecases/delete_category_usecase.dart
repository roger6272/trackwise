import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/category_repository.dart';

/// Parameters for [DeleteCategoryUseCase].
class DeleteCategoryParams extends Equatable {
  final String categoryId;

  const DeleteCategoryParams(this.categoryId);

  @override
  List<Object> get props => [categoryId];
}

/// Use case for deleting a category.
///
/// Soft-deletes the category and moves all items in it to uncategorized.
@lazySingleton
class DeleteCategoryUseCase extends UseCase<void, DeleteCategoryParams> {
  final CategoryRepository repository;

  DeleteCategoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteCategoryParams params) async {
    return await repository.deleteCategory(params.categoryId);
  }
}
