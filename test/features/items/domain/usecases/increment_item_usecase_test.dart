import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/items/domain/entities/item.dart';
import 'package:traxelos/features/items/domain/usecases/increment_item_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late IncrementItemUseCase useCase;
  late MockItemRepository mockRepository;

  setUp(() {
    mockRepository = MockItemRepository();
    useCase = IncrementItemUseCase(mockRepository);
  });

  group('IncrementItemUseCase', () {
    const itemId = 'test_item_1';

    test('should increment item successfully with default amount', () async {
      // Arrange
      final incrementedItem = testItem.copyWith(
        count: testItem.count + 1,
        todayCount: testItem.todayCount + 1,
      );
      when(() => mockRepository.incrementItem(any(), any()))
          .thenAnswer((_) async => Right(incrementedItem));

      final params = IncrementItemParams(itemId: itemId);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, Right(incrementedItem));
      verify(() => mockRepository.incrementItem(itemId, 1)).called(1);
    });

    test('should increment item with custom amount', () async {
      // Arrange
      const customAmount = 5;
      final incrementedItem = testItem.copyWith(
        count: testItem.count + customAmount,
        todayCount: testItem.todayCount + customAmount,
      );
      when(() => mockRepository.incrementItem(any(), any()))
          .thenAnswer((_) async => Right(incrementedItem));

      final params = IncrementItemParams(itemId: itemId, amount: customAmount);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, Right(incrementedItem));
      verify(() => mockRepository.incrementItem(itemId, customAmount)).called(1);
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to increment item');
      when(() => mockRepository.incrementItem(any(), any()))
          .thenAnswer((_) async => const Left(failure));

      final params = IncrementItemParams(itemId: itemId);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.incrementItem(itemId, 1)).called(1);
    });

    test('should verify repository called with correct params', () async {
      // Arrange
      const differentItemId = 'different_item';
      const amount = 3;
      when(() => mockRepository.incrementItem(any(), any()))
          .thenAnswer((_) async => Right(testItem));

      final params = IncrementItemParams(itemId: differentItemId, amount: amount);

      // Act
      await useCase(params);

      // Assert
      verify(() => mockRepository.incrementItem(differentItemId, amount)).called(1);
    });
  });

  group('IncrementItemParams', () {
    test('should have correct props for Equatable', () {
      // Arrange
      const params = IncrementItemParams(itemId: 'item_123', amount: 5);

      // Act
      final props = params.props;

      // Assert
      expect(props, ['item_123', 5]);
    });

    test('should use default amount of 1', () {
      // Arrange
      const params = IncrementItemParams(itemId: 'item_123');

      // Act & Assert
      expect(params.amount, 1);
      expect(params.props, ['item_123', 1]);
    });
  });
}
