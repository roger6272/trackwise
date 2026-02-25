import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/exceptions.dart';
import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/events/domain/entities/event_log.dart';
import 'package:traxelos/features/items/data/models/item_model.dart';
import 'package:traxelos/features/items/data/repositories/item_repository_impl.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late ItemRepositoryImpl repository;
  late MockItemRemoteDataSource mockDataSource;
  late MockEventLogRepository mockEventLogRepository;

  setUpAll(() {
    registerFallbackValue(testItemModel);
    registerFallbackValue(<EventLog>[]);
  });

  setUp(() {
    mockDataSource = MockItemRemoteDataSource();
    mockEventLogRepository = MockEventLogRepository();
    repository = ItemRepositoryImpl(mockDataSource, mockEventLogRepository);

    // Default mock for insertEvents (used by createItem)
    when(() => mockEventLogRepository.insertEvents(any()))
        .thenAnswer((_) async => const Right(null));
  });

  group('getItems', () {
    const userId = 'user_123';

    test('should return items when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.getItems(any()))
          .thenAnswer((_) async => testItemModels);

      // Act
      final result = await repository.getItems(userId);

      // Assert
      expect(result, Right(testItemModels));
      verify(() => mockDataSource.getItems(userId)).called(1);
      verifyNoMoreInteractions(mockDataSource);
    });

    test('should return ServerFailure when data source throws ServerException', () async {
      // Arrange
      when(() => mockDataSource.getItems(any()))
          .thenThrow(ServerException('Failed to fetch items'));

      // Act
      final result = await repository.getItems(userId);

      // Assert
      expect(result, isA<Left>());
      expect(
        (result as Left).value,
        isA<ServerFailure>().having(
          (f) => f.message,
          'message',
          contains('Failed to fetch items'),
        ),
      );
    });
  });

  group('getItem', () {
    const itemId = 'test_item_1';

    test('should return item when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.getItem(any()))
          .thenAnswer((_) async => testItemModel);

      // Act
      final result = await repository.getItem(itemId);

      // Assert
      expect(result, Right(testItemModel));
      verify(() => mockDataSource.getItem(itemId)).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.getItem(any()))
          .thenThrow(ServerException('Item not found'));

      // Act
      final result = await repository.getItem(itemId);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('watchItems', () {
    const userId = 'user_123';

    test('should return stream of items when data source succeeds', () {
      // Arrange
      final stream = Stream.value(testItemModels);
      when(() => mockDataSource.watchItems(any())).thenAnswer((_) => stream);

      // Act
      final result = repository.watchItems(userId);

      // Assert
      expect(result, emits(Right(testItemModels)));
      verify(() => mockDataSource.watchItems(userId)).called(1);
    });

    test('should return stream with ServerFailure when data source throws', () {
      // Arrange
      final stream = Stream<List<ItemModel>>.error(
        ServerException('Stream error'),
      );
      when(() => mockDataSource.watchItems(any())).thenAnswer((_) => stream);

      // Act
      final result = repository.watchItems(userId);

      // Assert
      expect(
        result,
        emits(isA<Left>()),
      );
    });
  });

  group('createItem', () {
    test('should return created item when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.createItem(any()))
          .thenAnswer((_) async => testItemModel);

      // Act
      final result = await repository.createItem(testItem);

      // Assert
      expect(result, Right(testItemModel));
      verify(() => mockDataSource.createItem(any())).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.createItem(any()))
          .thenThrow(ServerException('Failed to create item'));

      // Act
      final result = await repository.createItem(testItem);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('updateItem', () {
    test('should return updated item when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.updateItem(any()))
          .thenAnswer((_) async => testItemModel);

      // Act
      final result = await repository.updateItem(testItem);

      // Assert
      expect(result, Right(testItemModel));
      verify(() => mockDataSource.updateItem(any())).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.updateItem(any()))
          .thenThrow(ServerException('Failed to update item'));

      // Act
      final result = await repository.updateItem(testItem);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('deleteItem', () {
    const itemId = 'test_item_1';

    test('should return Right(null) when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.deleteItem(any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.deleteItem(itemId);

      // Assert
      expect(result, const Right(null));
      verify(() => mockDataSource.deleteItem(itemId)).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.deleteItem(any()))
          .thenThrow(ServerException('Failed to delete item'));

      // Act
      final result = await repository.deleteItem(itemId);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('incrementItem', () {
    const itemId = 'test_item_1';
    const amount = 5;

    test('should return incremented item when data source succeeds', () async {
      // Arrange
      final incrementedItem = ItemModel(
        id: testItemModel.id,
        name: testItemModel.name,
        count: testItemModel.count + amount,
        todayCount: testItemModel.todayCount + amount,
        incrementBy: testItemModel.incrementBy,
        reminder: testItemModel.reminder,
        reminderValue: testItemModel.reminderValue,
        lastResetTime: testItemModel.lastResetTime,
        lastUpdated: testItemModel.lastUpdated,
        userId: testItemModel.userId,
      );
      when(() => mockDataSource.incrementItem(any(), any()))
          .thenAnswer((_) async => incrementedItem);

      // Act
      final result = await repository.incrementItem(itemId, amount);

      // Assert
      expect(result, Right(incrementedItem));
      verify(() => mockDataSource.incrementItem(itemId, amount)).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.incrementItem(any(), any()))
          .thenThrow(ServerException('Failed to increment item'));

      // Act
      final result = await repository.incrementItem(itemId, amount);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('resetDailyCount', () {
    const itemId = 'test_item_1';

    test('should return Right(null) when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.resetDailyCount(any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.resetDailyCount(itemId);

      // Assert
      expect(result, const Right(null));
      verify(() => mockDataSource.resetDailyCount(itemId)).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.resetDailyCount(any()))
          .thenThrow(ServerException('Failed to reset daily count'));

      // Act
      final result = await repository.resetDailyCount(itemId);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('updateCycleNames', () {
    const itemId = 'test_item_1';
    final cycleNames = {'0': 'Alpha', '1': 'Beta'};

    test('should return Right(null) when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.updateCycleNames(any(), any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.updateCycleNames(itemId, cycleNames);

      // Assert
      expect(result, const Right(null));
      verify(() => mockDataSource.updateCycleNames(itemId, cycleNames)).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.updateCycleNames(any(), any()))
          .thenThrow(ServerException('Failed to update cycle names'));

      // Act
      final result = await repository.updateCycleNames(itemId, cycleNames);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('updateCycleNotes', () {
    const itemId = 'test_item_1';
    final cycleNotes = {'0': 'First note', '1': 'Second note'};

    test('should return Right(null) when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.updateCycleNotes(any(), any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.updateCycleNotes(itemId, cycleNotes);

      // Assert
      expect(result, const Right(null));
      verify(() => mockDataSource.updateCycleNotes(itemId, cycleNotes)).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.updateCycleNotes(any(), any()))
          .thenThrow(ServerException('Failed to update cycle notes'));

      // Act
      final result = await repository.updateCycleNotes(itemId, cycleNotes);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('claimItem', () {
    const itemId = 'test_item_1';
    const deviceInstanceId = 'device_abc';

    test('should return Right(null) when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.claimItem(any(), any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.claimItem(itemId, deviceInstanceId);

      // Assert
      expect(result, const Right(null));
      verify(() => mockDataSource.claimItem(itemId, deviceInstanceId)).called(1);
    });

    test('should return ClaimConflictFailure when data source throws ClaimConflictException', () async {
      // Arrange
      when(() => mockDataSource.claimItem(any(), any()))
          .thenThrow(ClaimConflictException('Item already claimed by other_device'));

      // Act
      final result = await repository.claimItem(itemId, deviceInstanceId);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ClaimConflictFailure>());
    });

    test('should return ServerFailure when data source throws ServerException', () async {
      // Arrange
      when(() => mockDataSource.claimItem(any(), any()))
          .thenThrow(ServerException('Failed to claim item'));

      // Act
      final result = await repository.claimItem(itemId, deviceInstanceId);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('releaseItem', () {
    const itemId = 'test_item_1';

    test('should return Right(null) when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.releaseItem(any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.releaseItem(itemId);

      // Assert
      expect(result, const Right(null));
      verify(() => mockDataSource.releaseItem(itemId)).called(1);
    });

    test('should return ServerFailure when data source throws ServerException', () async {
      // Arrange
      when(() => mockDataSource.releaseItem(any()))
          .thenThrow(ServerException('Failed to release item'));

      // Act
      final result = await repository.releaseItem(itemId);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('releaseAllClaims', () {
    const deviceInstanceId = 'device_abc';
    const userId = 'user_123';

    test('should return Right(null) when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.releaseAllClaims(any(), any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.releaseAllClaims(deviceInstanceId, userId);

      // Assert
      expect(result, const Right(null));
      verify(() => mockDataSource.releaseAllClaims(deviceInstanceId, userId)).called(1);
    });

    test('should return ServerFailure when data source throws ServerException', () async {
      // Arrange
      when(() => mockDataSource.releaseAllClaims(any(), any()))
          .thenThrow(ServerException('Failed to release all claims'));

      // Act
      final result = await repository.releaseAllClaims(deviceInstanceId, userId);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });
}
