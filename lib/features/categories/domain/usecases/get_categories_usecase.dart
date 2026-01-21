import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Parameters for [GetCategoriesUseCase].
class GetCategoriesParams extends Equatable {
  final String userId;

  const GetCategoriesParams(this.userId);

  @override
  List<Object> get props => [userId];
}

/// Use case for fetching all categories for a user.
@lazySingleton
class GetCategoriesUseCase extends UseCase<List<Category>, GetCategoriesParams> {
  final CategoryRepository repository;

  GetCategoriesUseCase(this.repository);

  @override
  Future<Either<Failure, List<Category>>> call(GetCategoriesParams params) async {
    return await repository.getCategories(params.userId);
  }
}
