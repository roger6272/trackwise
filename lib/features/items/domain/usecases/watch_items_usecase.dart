import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/item.dart';
import '../repositories/item_repository.dart';
import 'get_items_usecase.dart';

/// Use case for watching items with real-time updates.
///
/// Returns a stream that emits the latest items list whenever
/// Firestore data changes. This is used for real-time UI updates.
///
/// Note: This use case doesn't extend UseCase<T, Params> because it returns
/// a Stream instead of a Future. The base UseCase class is designed for
/// Future-based operations.
///
/// Example:
/// ```dart
/// final stream = watchItemsUseCase(GetItemsParams('user_123'));
/// stream.listen((either) {
///   either.fold(
///     (failure) => print('Error: ${failure.message}'),
///     (items) => print('Items updated: ${items.length}'),
///   );
/// });
/// ```
@lazySingleton
class WatchItemsUseCase {
  final ItemRepository repository;

  WatchItemsUseCase(this.repository);

  /// Watches items for the given user.
  ///
  /// Returns a stream of Either<Failure, List<Item>> that emits
  /// whenever the items collection changes in Firestore.
  ///
  /// Params:
  /// - [params]: Contains userId to watch items for
  ///
  /// Returns:
  /// - Stream<Right(List<Item>)>: Stream of updated items
  /// - Stream<Left(ServerFailure)>: Stream error occurred
  Stream<Either<Failure, List<Item>>> call(GetItemsParams params) {
    return repository.watchItems(params.userId);
  }
}
