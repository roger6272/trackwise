import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/items/domain/entities/item.dart';
import 'package:trackwise/features/items/domain/usecases/update_item_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late UpdateItemUseCase useCase;
  late MockItemRepository mockRepository;

  setUp(() {
    mockRepository = MockItemRepository();
    useCase = UpdateItemUseCase(mockRepository);

    // Register fallback value for Item
    registerFallbackValue(testItem);
  });

  group('UpdateItemUseCase', () {
    final validItem = testItem.copyWith(name: 'Updated Coffee');
    final validParams = UpdateItemParams(validItem);

    test('should update item when all validations pass', () async {
      // Arrange
      when(() => mockRepository.updateItem(any()))
          .thenAnswer((_) async => Right(validItem));

      // Act
      final result = await useCase(validParams);

      // Assert
      expect(result, isA<Right<Failure, Item>>());
      verify(() => mockRepository.updateItem(validItem)).called(1);
    });

    test('should return ValidationFailure for empty name', () async {
      // Arrange
      final invalidItem = testItem.copyWith(name: '');
      final params = UpdateItemParams(invalidItem);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('name'));
      verifyNever(() => mockRepository.updateItem(any()));
    });

    test('should return ValidationFailure for name > 30 chars', () async {
      // Arrange
      final invalidItem = testItem.copyWith(name: 'a' * 31);
      final params = UpdateItemParams(invalidItem);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('30'));
      verifyNever(() => mockRepository.updateItem(any()));
    });

    test('should return ValidationFailure for invalid incrementBy', () async {
      // Arrange
      final invalidItem = testItem.copyWith(incrementBy: 0);
      final params = UpdateItemParams(invalidItem);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      verifyNever(() => mockRepository.updateItem(any()));
    });

    test('should return ValidationFailure for invalid reminderValue', () async {
      // Arrange
      final invalidItem = testItem.copyWith(reminderValue: -1);
      final params = UpdateItemParams(invalidItem);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      verifyNever(() => mockRepository.updateItem(any()));
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to update item');
      when(() => mockRepository.updateItem(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(validParams);

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.updateItem(validItem)).called(1);
    });
  });

  group('UpdateItemParams', () {
    test('should have correct props for Equatable', () {
      // Arrange
      final params = UpdateItemParams(testItem);

      // Act
      final props = params.props;

      // Assert
      expect(props, [testItem]);
    });
  });
}
