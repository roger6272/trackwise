import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/domain/usecases/get_categories_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late GetCategoriesUseCase useCase;
  late MockCategoryRepository mockRepository;

  setUp(() {
    mockRepository = MockCategoryRepository();
    useCase = GetCategoriesUseCase(mockRepository);
  });

  group('GetCategoriesUseCase', () {
    const userId = 'user_123';

    test('should return categories when repository succeeds', () async {
      // Arrange
      when(() => mockRepository.getCategories(any()))
          .thenAnswer((_) async => Right(testCategories));

      // Act
      final result = await useCase(const GetCategoriesParams(userId));

      // Assert
      expect(result, isA<Right<Failure, List<Category>>>());
      verify(() => mockRepository.getCategories(userId)).called(1);
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to fetch categories');
      when(() => mockRepository.getCategories(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const GetCategoriesParams(userId));

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.getCategories(userId)).called(1);
    });

    test('should return empty list when no categories exist', () async {
      // Arrange
      when(() => mockRepository.getCategories(any()))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(const GetCategoriesParams(userId));

      // Assert
      expect(result, const Right(<Category>[]));
    });
  });

  group('GetCategoriesParams', () {
    test('should have correct props for Equatable', () {
      const params = GetCategoriesParams('user_123');
      expect(params.props, ['user_123']);
    });

    test('should be equal when userId is same', () {
      const params1 = GetCategoriesParams('user_123');
      const params2 = GetCategoriesParams('user_123');

      expect(params1, equals(params2));
      expect(params1.hashCode, equals(params2.hashCode));
    });
  });
}
