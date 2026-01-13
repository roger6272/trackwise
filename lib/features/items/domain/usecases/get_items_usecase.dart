import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/item.dart';
import '../repositories/item_repository.dart';

/// Parameters for GetItemsUseCase.
///
/// Contains the userId to fetch items for.
class GetItemsParams extends Equatable {
  final String userId;

  const GetItemsParams(this.userId);

  @override
  List<Object> get props => [userId];
}

/// Use case for fetching all items for a user (one-time query).
///
/// This is a simple pass-through use case that delegates to the repository.
/// Use [WatchItemsUseCase] for real-time updates instead.
///
/// Example:
/// ```dart
/// final result = await getItemsUseCase(GetItemsParams('user_123'));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (items) => print('Found ${items.length} items'),
/// );
/// ```
@lazySingleton
class GetItemsUseCase extends UseCase<List<Item>, GetItemsParams> {
  final ItemRepository repository;

  GetItemsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Item>>> call(GetItemsParams params) async {
    return await repository.getItems(params.userId);
  }
}
