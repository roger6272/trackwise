import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/item.dart';
import '../repositories/item_repository.dart';

/// Parameters for IncrementItemUseCase.
///
/// Contains the item ID and the amount to increment by.
class IncrementItemParams extends Equatable {
  /// The ID of the item to increment
  final String itemId;

  /// The amount to add to count and todayCount
  ///
  /// Defaults to 1 if not specified. The repository may use the item's
  /// incrementBy value if this is not provided.
  final int amount;

  const IncrementItemParams({
    required this.itemId,
    this.amount = 1,
  });

  @override
  List<Object> get props => [itemId, amount];
}

/// Use case for incrementing an item's count.
///
/// Increments both count (cumulative) and todayCount (daily) by the specified amount.
/// Also updates the lastUpdated timestamp and creates an EventLog entry.
///
/// This is used when incrementing from the app UI (not just Bluetooth events).
///
/// Example:
/// ```dart
/// // Increment by the item's default incrementBy value
/// final result = await incrementItemUseCase(
///   IncrementItemParams(itemId: 'item_123', amount: 1),
/// );
///
/// // Increment by a custom amount
/// final result = await incrementItemUseCase(
///   IncrementItemParams(itemId: 'item_123', amount: 5),
/// );
///
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (item) => print('New count: ${item.count}'),
/// );
/// ```
@lazySingleton
class IncrementItemUseCase extends UseCase<Item, IncrementItemParams> {
  final ItemRepository repository;

  IncrementItemUseCase(this.repository);

  @override
  Future<Either<Failure, Item>> call(IncrementItemParams params) async {
    return await repository.incrementItem(params.itemId, params.amount);
  }
}
