import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Parameters for [WatchCategoriesUseCase].
class WatchCategoriesParams extends Equatable {
  final String userId;

  const WatchCategoriesParams(this.userId);

  @override
  List<Object> get props => [userId];
}

/// Use case for watching categories with real-time updates.
///
/// Returns a stream that emits whenever categories change.
@lazySingleton
class WatchCategoriesUseCase {
  final CategoryRepository repository;

  WatchCategoriesUseCase(this.repository);

  Stream<Either<Failure, List<Category>>> call(WatchCategoriesParams params) {
    return repository.watchCategories(params.userId);
  }
}
