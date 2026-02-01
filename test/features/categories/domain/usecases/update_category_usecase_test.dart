import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/domain/usecases/update_category_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late UpdateCategoryUseCase useCase;
  late MockCategoryRepository mockRepository;

  setUp(() {
    mockRepository = MockCategoryRepository();
    useCase = UpdateCategoryUseCase(mockRepository);

    registerFallbackValue(testCategory);
  });

  group('UpdateCategoryUseCase', () {
    test('should update category when all validations pass', () async {
      // Arrange
      when(() => mockRepository.categoryNameExists(any(), any(),
              excludeId: any(named: 'excludeId')))
          .thenAnswer((_) async => const Right(false));
      when(() => mockRepository.updateCategory(any()))
          .thenAnswer((_) async => Right(testCategory));

      // Act
      final result = await useCase(UpdateCategoryParams(testCategory));

      // Assert
      expect(result, isA<Right<Failure, Category>>());
      verify(() => mockRepository.categoryNameExists(
            testCategory.userId,
            testCategory.name,
            excludeId: testCategory.id,
          )).called(1);
      verify(() => mockRepository.updateCategory(testCategory)).called(1);
    });

    test('should return ValidationFailure for empty name', () async {
      // Arrange
      final invalidCategory = testCategory.copyWith(name: '');

      // Act
      final result = await useCase(UpdateCategoryParams(invalidCategory));

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      verifyNever(() => mockRepository.updateCategory(any()));
    });

    test('should return ValidationFailure for name > 30 chars', () async {
      // Arrange
      final invalidCategory = testCategory.copyWith(name: 'a' * 31);

      // Act
      final result = await useCase(UpdateCategoryParams(invalidCategory));

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('30'));
      verifyNever(() => mockRepository.updateCategory(any()));
    });

    test('should return ValidationFailure when name already exists', () async {
      // Arrange
      when(() => mockRepository.categoryNameExists(any(), any(),
              excludeId: any(named: 'excludeId')))
          .thenAnswer((_) async => const Right(true));

      // Act
      final result = await useCase(UpdateCategoryParams(testCategory));

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('already exists'));
      verifyNever(() => mockRepository.updateCategory(any()));
    });

    test('should return failure when categoryNameExists fails', () async {
      // Arrange
      when(() => mockRepository.categoryNameExists(any(), any(),
              excludeId: any(named: 'excludeId')))
          .thenAnswer(
              (_) async => const Left(ServerFailure('Check failed')));

      // Act
      final result = await useCase(UpdateCategoryParams(testCategory));

      // Assert
      expect(result, isA<Left>());
      verifyNever(() => mockRepository.updateCategory(any()));
    });

    test('should return ServerFailure when repository update fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to update');
      when(() => mockRepository.categoryNameExists(any(), any(),
              excludeId: any(named: 'excludeId')))
          .thenAnswer((_) async => const Right(false));
      when(() => mockRepository.updateCategory(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(UpdateCategoryParams(testCategory));

      // Assert
      expect(result, const Left(failure));
    });
  });

  group('UpdateCategoryParams', () {
    test('should have correct props for Equatable', () {
      final params = UpdateCategoryParams(testCategory);
      expect(params.props, [testCategory]);
    });

    test('should be equal when category is same', () {
      final params1 = UpdateCategoryParams(testCategory);
      final params2 = UpdateCategoryParams(testCategory);

      expect(params1, equals(params2));
    });
  });
}
