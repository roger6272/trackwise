import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/categories/domain/usecases/delete_category_usecase.dart';

import '../../helpers/test_helper.dart';

void main() {
  late DeleteCategoryUseCase useCase;
  late MockCategoryRepository mockRepository;

  setUp(() {
    mockRepository = MockCategoryRepository();
    useCase = DeleteCategoryUseCase(mockRepository);
  });

  group('DeleteCategoryUseCase', () {
    const categoryId = 'test_category_1';

    test('should delete category when repository succeeds', () async {
      // Arrange
      when(() => mockRepository.deleteCategory(any()))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(const DeleteCategoryParams(categoryId));

      // Assert
      expect(result, const Right(null));
      verify(() => mockRepository.deleteCategory(categoryId)).called(1);
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to delete');
      when(() => mockRepository.deleteCategory(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const DeleteCategoryParams(categoryId));

      // Assert
      expect(result, const Left(failure));
    });
  });

  group('DeleteCategoryParams', () {
    test('should have correct props for Equatable', () {
      const params = DeleteCategoryParams('cat_1');
      expect(params.props, ['cat_1']);
    });

    test('should be equal when categoryId is same', () {
      const params1 = DeleteCategoryParams('cat_1');
      const params2 = DeleteCategoryParams('cat_1');

      expect(params1, equals(params2));
    });

    test('should not be equal when categoryId differs', () {
      const params1 = DeleteCategoryParams('cat_1');
      const params2 = DeleteCategoryParams('cat_2');

      expect(params1, isNot(equals(params2)));
    });
  });
}
