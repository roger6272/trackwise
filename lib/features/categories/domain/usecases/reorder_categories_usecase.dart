import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Parameters for [ReorderCategoriesUseCase].
class ReorderCategoriesParams extends Equatable {
  final List<Category> categories;

  const ReorderCategoriesParams(this.categories);

  @override
  List<Object> get props => [categories];
}

/// Use case for reordering categories.
///
/// Updates the order field of each category in the list.
@lazySingleton
class ReorderCategoriesUseCase extends UseCase<void, ReorderCategoriesParams> {
  final CategoryRepository repository;

  ReorderCategoriesUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ReorderCategoriesParams params) async {
    return await repository.reorderCategories(params.categories);
  }
}
