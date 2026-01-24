import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../datasources/item_remote_datasource.dart';
import '../models/item_model.dart';

/// Implementation of ItemRepository that delegates to ItemRemoteDataSource.
///
/// This class sits between the domain layer (use cases) and the data layer
/// (data sources). It converts domain entities to data models and vice versa,
/// and converts exceptions thrown by the data source into Failure objects
/// wrapped in Either.
///
/// Error handling flow:
/// 1. Data source throws ServerException
/// 2. Repository catches exception
/// 3. Repository returns Left(ServerFailure(...))
/// 4. Use cases receive Either<Failure, T>
/// 5. BLoC handles success/failure with fold()
@LazySingleton(as: ItemRepository)
class ItemRepositoryImpl implements ItemRepository {
  final ItemRemoteDataSource remoteDataSource;

  ItemRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<Item>>> getItems(String userId) async {
    try {
      final items = await remoteDataSource.getItems(userId);
      return Right(items);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Item>> getItem(String itemId) async {
    try {
      final item = await remoteDataSource.getItem(itemId);
      return Right(item);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, List<Item>>> watchItems(String userId) {
    return remoteDataSource.watchItems(userId)
        .map<Either<Failure, List<Item>>>((items) => Right<Failure, List<Item>>(items))
        .onErrorResume((error, stackTrace) {
      if (error is ServerException) {
        return Stream<Either<Failure, List<Item>>>.value(
            Left(ServerFailure(error.message)));
      }
      return Stream<Either<Failure, List<Item>>>.value(
          Left(ServerFailure('Unexpected error: $error')));
    });
  }

  @override
  Future<Either<Failure, Item>> createItem(Item item) async {
    try {
      final itemModel = ItemModel(
        id: item.id,
        name: item.name,
        count: item.count,
        todayCount: item.todayCount,
        incrementBy: item.incrementBy,
        reminder: item.reminder,
        reminderValue: item.reminderValue,
        lastResetTime: item.lastResetTime,
        lastUpdated: item.lastUpdated,
        userId: item.userId,
        order: item.order,
        initialCount: item.initialCount,
        goal: item.goal,
        categoryId: item.categoryId,
        categoryOrder: item.categoryOrder,
      );
      final created = await remoteDataSource.createItem(itemModel);
      return Right(created);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Item>> updateItem(Item item) async {
    try {
      final itemModel = ItemModel(
        id: item.id,
        name: item.name,
        count: item.count,
        todayCount: item.todayCount,
        incrementBy: item.incrementBy,
        reminder: item.reminder,
        reminderValue: item.reminderValue,
        lastResetTime: item.lastResetTime,
        lastUpdated: item.lastUpdated,
        userId: item.userId,
        order: item.order,
        initialCount: item.initialCount,
        goal: item.goal,
        categoryId: item.categoryId,
        categoryOrder: item.categoryOrder,
      );
      final updated = await remoteDataSource.updateItem(itemModel);
      return Right(updated);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteItem(String itemId) async {
    try {
      await remoteDataSource.deleteItem(itemId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Item>> incrementItem(String itemId, int amount) async {
    try {
      final item = await remoteDataSource.incrementItem(itemId, amount);
      return Right(item);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> resetDailyCount(String itemId) async {
    try {
      await remoteDataSource.resetDailyCount(itemId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> batchUpdateCounts(
    String userId,
    List<Map<String, dynamic>> itemData,
  ) async {
    try {
      await remoteDataSource.batchUpdateCounts(userId, itemData);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Item>>> getDeletedItems(String userId) async {
    try {
      final items = await remoteDataSource.getDeletedItems(userId);
      return Right(items);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> restoreItem(String itemId) async {
    try {
      await remoteDataSource.restoreItem(itemId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error restoring item: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> reorderItems(List<Item> items) async {
    try {
      final itemModels = items.map((item) => ItemModel(
        id: item.id,
        name: item.name,
        count: item.count,
        todayCount: item.todayCount,
        incrementBy: item.incrementBy,
        reminder: item.reminder,
        reminderValue: item.reminderValue,
        lastResetTime: item.lastResetTime,
        lastUpdated: item.lastUpdated,
        userId: item.userId,
        deletedAt: item.deletedAt,
        order: item.order,
        initialCount: item.initialCount,
        goal: item.goal,
        categoryId: item.categoryId,
        categoryOrder: item.categoryOrder,
      )).toList();
      await remoteDataSource.reorderItems(itemModels);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> reorderItemsInCategory(List<Item> items) async {
    try {
      final itemModels = items.map((item) => ItemModel(
        id: item.id,
        name: item.name,
        count: item.count,
        todayCount: item.todayCount,
        incrementBy: item.incrementBy,
        reminder: item.reminder,
        reminderValue: item.reminderValue,
        lastResetTime: item.lastResetTime,
        lastUpdated: item.lastUpdated,
        userId: item.userId,
        deletedAt: item.deletedAt,
        order: item.order,
        initialCount: item.initialCount,
        goal: item.goal,
        categoryId: item.categoryId,
        categoryOrder: item.categoryOrder,
      )).toList();
      await remoteDataSource.reorderItemsInCategory(itemModels);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> moveItemToCategory(
    String itemId,
    String? newCategoryId,
  ) async {
    try {
      // Get the item to find userId
      final item = await remoteDataSource.getItem(itemId);

      // Get max categoryOrder for the target category
      final maxOrder = await remoteDataSource.getMaxCategoryOrder(
        item.userId,
        newCategoryId,
      );

      await remoteDataSource.moveItemToCategory(
        itemId,
        newCategoryId,
        maxOrder + 1,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, int>> getMaxCategoryOrder(
    String userId,
    String? categoryId,
  ) async {
    try {
      final maxOrder = await remoteDataSource.getMaxCategoryOrder(
        userId,
        categoryId,
      );
      return Right(maxOrder);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Item>>> resetAllItems(String userId) async {
    try {
      final models = await remoteDataSource.resetAllItems(userId);
      final items = models.map((model) => model.toEntity()).toList();
      return Right(items);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
