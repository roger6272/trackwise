import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/domain/usecases/create_category_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late CreateCategoryUseCase useCase;
  late MockCategoryRepository mockRepository;

  setUp(() {
    mockRepository = MockCategoryRepository();
    useCase = CreateCategoryUseCase(mockRepository);

    registerFallbackValue(testCategory);
  });

  group('CreateCategoryUseCase', () {
    const userId = 'user_123';

    const validParams = CreateCategoryParams(
      name: 'Electronics',
      userId: userId,
    );

    test('should create category when all validations pass', () async {
      // Arrange
      when(() => mockRepository.categoryNameExists(any(), any()))
          .thenAnswer((_) async => const Right(false));
      when(() => mockRepository.createCategory(any()))
          .thenAnswer((_) async => Right(testCategory));

      // Act
      final result = await useCase(validParams);

      // Assert
      expect(result, isA<Right<Failure, Category>>());
      verify(() => mockRepository.categoryNameExists(userId, 'Electronics'))
          .called(1);
      verify(() => mockRepository.createCategory(any())).called(1);
    });

    test('should return ValidationFailure for empty name', () async {
      // Arrange
      const params = CreateCategoryParams(name: '', userId: userId);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('name'));
      verifyNever(() => mockRepository.createCategory(any()));
    });

    test('should return ValidationFailure for whitespace-only name', () async {
      // Arrange
      const params = CreateCategoryParams(name: '   ', userId: userId);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      verifyNever(() => mockRepository.createCategory(any()));
    });

    test('should return ValidationFailure for name > 30 chars', () async {
      // Arrange
      final params = CreateCategoryParams(
        name: 'a' * 31,
        userId: userId,
      );

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('30'));
      verifyNever(() => mockRepository.createCategory(any()));
    });

    test('should return ValidationFailure when name already exists', () async {
      // Arrange
      when(() => mockRepository.categoryNameExists(any(), any()))
          .thenAnswer((_) async => const Right(true));

      // Act
      final result = await useCase(validParams);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('already exists'));
      verifyNever(() => mockRepository.createCategory(any()));
    });

    test('should return failure when categoryNameExists fails', () async {
      // Arrange
      when(() => mockRepository.categoryNameExists(any(), any()))
          .thenAnswer(
              (_) async => const Left(ServerFailure('Check failed')));

      // Act
      final result = await useCase(validParams);

      // Assert
      expect(result, isA<Left>());
      verifyNever(() => mockRepository.createCategory(any()));
    });

    test('should return ServerFailure when repository create fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to create');
      when(() => mockRepository.categoryNameExists(any(), any()))
          .thenAnswer((_) async => const Right(false));
      when(() => mockRepository.createCategory(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(validParams);

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.createCategory(any())).called(1);
    });
  });

  group('CreateCategoryParams', () {
    test('should have correct props for Equatable', () {
      const params = CreateCategoryParams(
        name: 'Electronics',
        userId: 'user_123',
      );

      expect(params.props, ['Electronics', 'user_123']);
    });

    test('should be equal when all properties are same', () {
      const params1 = CreateCategoryParams(
        name: 'Electronics',
        userId: 'user_123',
      );
      const params2 = CreateCategoryParams(
        name: 'Electronics',
        userId: 'user_123',
      );

      expect(params1, equals(params2));
      expect(params1.hashCode, equals(params2.hashCode));
    });
  });
}
