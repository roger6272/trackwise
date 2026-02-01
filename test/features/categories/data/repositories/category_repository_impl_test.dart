import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/exceptions.dart';
import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/categories/data/models/category_model.dart';
import 'package:traxelos/features/categories/data/repositories/category_repository_impl.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late CategoryRepositoryImpl repository;
  late MockCategoryRemoteDataSource mockDataSource;

  setUpAll(() {
    registerFallbackValue(testCategoryModel);
    registerFallbackValue(<CategoryModel>[]);
  });

  setUp(() {
    mockDataSource = MockCategoryRemoteDataSource();
    repository = CategoryRepositoryImpl(mockDataSource);
  });

  group('getCategories', () {
    const userId = 'user_123';

    test('should return categories when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.getCategories(any()))
          .thenAnswer((_) async => testCategoryModels);

      // Act
      final result = await repository.getCategories(userId);

      // Assert
      expect(result, isA<Right>());
      result.fold(
        (_) => fail('should be Right'),
        (categories) => expect(categories.length, testCategoryModels.length),
      );
      verify(() => mockDataSource.getCategories(userId)).called(1);
      verifyNoMoreInteractions(mockDataSource);
    });

    test('should return ServerFailure when data source throws ServerException',
        () async {
      // Arrange
      when(() => mockDataSource.getCategories(any()))
          .thenThrow(ServerException('Failed to fetch categories'));

      // Act
      final result = await repository.getCategories(userId);

      // Assert
      expect(result, isA<Left>());
      expect(
        (result as Left).value,
        isA<ServerFailure>().having(
          (f) => f.message,
          'message',
          contains('Failed to fetch categories'),
        ),
      );
    });
  });

  group('watchCategories', () {
    const userId = 'user_123';

    test('should return stream of categories when data source succeeds', () {
      // Arrange
      final stream = Stream.value(testCategoryModels);
      when(() => mockDataSource.watchCategories(any()))
          .thenAnswer((_) => stream);

      // Act
      final result = repository.watchCategories(userId);

      // Assert
      expect(result, emits(isA<Right>()));
      verify(() => mockDataSource.watchCategories(userId)).called(1);
    });

    test(
        'should return stream with ServerFailure when data source emits error',
        () {
      // Arrange
      final stream = Stream<List<CategoryModel>>.error(
        ServerException('Stream error'),
      );
      when(() => mockDataSource.watchCategories(any()))
          .thenAnswer((_) => stream);

      // Act
      final result = repository.watchCategories(userId);

      // Assert
      expect(result, emits(isA<Left>()));
    });
  });

  group('createCategory', () {
    test('should return created category when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.getNextOrderValue(any()))
          .thenAnswer((_) async => 0);
      when(() => mockDataSource.createCategory(any()))
          .thenAnswer((_) async => testCategoryModel);

      // Act
      final result = await repository.createCategory(testCategory);

      // Assert
      expect(result, isA<Right>());
      verify(() => mockDataSource.getNextOrderValue(testCategory.userId))
          .called(1);
      verify(() => mockDataSource.createCategory(any())).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.getNextOrderValue(any()))
          .thenAnswer((_) async => 0);
      when(() => mockDataSource.createCategory(any()))
          .thenThrow(ServerException('Failed to create category'));

      // Act
      final result = await repository.createCategory(testCategory);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });

    test('should normalize category name to title case', () async {
      // Arrange
      when(() => mockDataSource.getNextOrderValue(any()))
          .thenAnswer((_) async => 0);
      when(() => mockDataSource.createCategory(any()))
          .thenAnswer((_) async => testCategoryModel);

      final categoryWithLowercaseName = testCategory.copyWith(name: 'my category');

      // Act
      await repository.createCategory(categoryWithLowercaseName);

      // Assert
      final captured = verify(() => mockDataSource.createCategory(captureAny()))
          .captured
          .single as CategoryModel;
      expect(captured.name, 'My Category');
    });
  });

  group('updateCategory', () {
    test('should return updated category when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.updateCategory(any()))
          .thenAnswer((_) async => testCategoryModel);

      // Act
      final result = await repository.updateCategory(testCategory);

      // Assert
      expect(result, isA<Right>());
      verify(() => mockDataSource.updateCategory(any())).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.updateCategory(any()))
          .thenThrow(ServerException('Failed to update category'));

      // Act
      final result = await repository.updateCategory(testCategory);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });

    test('should normalize category name to title case', () async {
      // Arrange
      when(() => mockDataSource.updateCategory(any()))
          .thenAnswer((_) async => testCategoryModel);

      final categoryWithLowercaseName =
          testCategory.copyWith(name: 'updated name');

      // Act
      await repository.updateCategory(categoryWithLowercaseName);

      // Assert
      final captured = verify(() => mockDataSource.updateCategory(captureAny()))
          .captured
          .single as CategoryModel;
      expect(captured.name, 'Updated Name');
    });
  });

  group('deleteCategory', () {
    const categoryId = 'test_category_1';

    test('should return Right(null) when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.deleteCategory(any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.deleteCategory(categoryId);

      // Assert
      expect(result, const Right(null));
      verify(() => mockDataSource.deleteCategory(categoryId)).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.deleteCategory(any()))
          .thenThrow(ServerException('Failed to delete category'));

      // Act
      final result = await repository.deleteCategory(categoryId);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('reorderCategories', () {
    test('should return Right(null) when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.reorderCategories(any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.reorderCategories(testCategories);

      // Assert
      expect(result, const Right(null));
      verify(() => mockDataSource.reorderCategories(any())).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.reorderCategories(any()))
          .thenThrow(ServerException('Failed to reorder'));

      // Act
      final result = await repository.reorderCategories(testCategories);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('categoryNameExists', () {
    const userId = 'user_123';
    const name = 'Electronics';

    test('should return true when name exists', () async {
      // Arrange
      when(() => mockDataSource.categoryNameExists(any(), any(),
              excludeId: any(named: 'excludeId')))
          .thenAnswer((_) async => true);

      // Act
      final result = await repository.categoryNameExists(userId, name);

      // Assert
      expect(result, const Right(true));
    });

    test('should return false when name does not exist', () async {
      // Arrange
      when(() => mockDataSource.categoryNameExists(any(), any(),
              excludeId: any(named: 'excludeId')))
          .thenAnswer((_) async => false);

      // Act
      final result = await repository.categoryNameExists(userId, name);

      // Assert
      expect(result, const Right(false));
    });

    test('should pass excludeId to data source', () async {
      // Arrange
      when(() => mockDataSource.categoryNameExists(any(), any(),
              excludeId: any(named: 'excludeId')))
          .thenAnswer((_) async => false);

      // Act
      await repository.categoryNameExists(userId, name,
          excludeId: 'exclude_1');

      // Assert
      verify(() => mockDataSource.categoryNameExists(userId, name,
          excludeId: 'exclude_1')).called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.categoryNameExists(any(), any(),
              excludeId: any(named: 'excludeId')))
          .thenThrow(ServerException('Check failed'));

      // Act
      final result = await repository.categoryNameExists(userId, name);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });

  group('getItemCountForCategory', () {
    const userId = 'user_123';
    const categoryId = 'test_category_1';

    test('should return count when data source succeeds', () async {
      // Arrange
      when(() => mockDataSource.getItemCountForCategory(any(), any()))
          .thenAnswer((_) async => 5);

      // Act
      final result =
          await repository.getItemCountForCategory(categoryId, userId);

      // Assert
      expect(result, const Right(5));
      verify(() => mockDataSource.getItemCountForCategory(categoryId, userId))
          .called(1);
    });

    test('should return ServerFailure when data source throws', () async {
      // Arrange
      when(() => mockDataSource.getItemCountForCategory(any(), any()))
          .thenThrow(ServerException('Count failed'));

      // Act
      final result =
          await repository.getItemCountForCategory(categoryId, userId);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ServerFailure>());
    });
  });
}
