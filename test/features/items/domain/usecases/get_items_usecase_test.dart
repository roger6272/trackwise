import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/items/domain/entities/item.dart';
import 'package:trackwise/features/items/domain/usecases/get_items_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late GetItemsUseCase useCase;
  late MockItemRepository mockRepository;

  setUp(() {
    mockRepository = MockItemRepository();
    useCase = GetItemsUseCase(mockRepository);
  });

  group('GetItemsUseCase', () {
    const userId = 'user_123';

    test('should get items from repository when successful', () async {
      // Arrange
      when(() => mockRepository.getItems(any()))
          .thenAnswer((_) async => Right(testItems));

      // Act
      final result = await useCase(GetItemsParams(userId));

      // Assert
      expect(result, Right(testItems));
      verify(() => mockRepository.getItems(userId)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to fetch items');
      when(() => mockRepository.getItems(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(GetItemsParams(userId));

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.getItems(userId)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should call repository with correct userId', () async {
      // Arrange
      const differentUserId = 'different_user';
      when(() => mockRepository.getItems(any()))
          .thenAnswer((_) async => Right(testItems));

      // Act
      await useCase(GetItemsParams(differentUserId));

      // Assert
      verify(() => mockRepository.getItems(differentUserId)).called(1);
    });

    test('should return empty list when repository returns empty list', () async {
      // Arrange
      when(() => mockRepository.getItems(any()))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(GetItemsParams(userId));

      // Assert
      expect(result, Right<Failure, List<Item>>(const []));
      verify(() => mockRepository.getItems(userId)).called(1);
    });
  });
}
