import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/domain/usecases/reorder_categories_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late ReorderCategoriesUseCase useCase;
  late MockCategoryRepository mockRepository;

  setUp(() {
    mockRepository = MockCategoryRepository();
    useCase = ReorderCategoriesUseCase(mockRepository);

    registerFallbackValue(<Category>[]);
  });

  group('ReorderCategoriesUseCase', () {
    test('should reorder categories when repository succeeds', () async {
      // Arrange
      when(() => mockRepository.reorderCategories(any()))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result =
          await useCase(ReorderCategoriesParams(testCategories));

      // Assert
      expect(result, const Right(null));
      verify(() => mockRepository.reorderCategories(testCategories)).called(1);
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to reorder');
      when(() => mockRepository.reorderCategories(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result =
          await useCase(ReorderCategoriesParams(testCategories));

      // Assert
      expect(result, const Left(failure));
    });
  });

  group('ReorderCategoriesParams', () {
    test('should have correct props for Equatable', () {
      final params = ReorderCategoriesParams(testCategories);
      expect(params.props, [testCategories]);
    });

    test('should be equal when categories are same', () {
      final params1 = ReorderCategoriesParams(testCategories);
      final params2 = ReorderCategoriesParams(testCategories);

      expect(params1, equals(params2));
    });
  });
}
