import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/domain/usecases/watch_categories_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late WatchCategoriesUseCase useCase;
  late MockCategoryRepository mockRepository;

  setUp(() {
    mockRepository = MockCategoryRepository();
    useCase = WatchCategoriesUseCase(mockRepository);
  });

  group('WatchCategoriesUseCase', () {
    const userId = 'user_123';

    test('should return stream of categories from repository', () {
      // Arrange
      final stream =
          Stream.value(Right<Failure, List<Category>>(testCategories));
      when(() => mockRepository.watchCategories(any()))
          .thenAnswer((_) => stream);

      // Act
      final result = useCase(const WatchCategoriesParams(userId));

      // Assert
      expect(result, stream);
      verify(() => mockRepository.watchCategories(userId)).called(1);
    });

    test('should return stream with failure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Stream error');
      final stream =
          Stream.value(const Left<Failure, List<Category>>(failure));
      when(() => mockRepository.watchCategories(any()))
          .thenAnswer((_) => stream);

      // Act
      final result = useCase(const WatchCategoriesParams(userId));

      // Assert
      await expectLater(result, emits(const Left(failure)));
      verify(() => mockRepository.watchCategories(userId)).called(1);
    });

    test('should emit multiple values from stream', () async {
      // Arrange
      final stream = Stream.fromIterable([
        Right<Failure, List<Category>>(testCategories),
        Right<Failure, List<Category>>([testCategory]),
        const Right<Failure, List<Category>>([]),
      ]);
      when(() => mockRepository.watchCategories(any()))
          .thenAnswer((_) => stream);

      // Act
      final result = useCase(const WatchCategoriesParams(userId));

      // Assert
      await expectLater(
        result,
        emitsInOrder([
          predicate<Either<Failure, List<Category>>>((either) =>
              either.isRight() &&
              either.fold((_) => false, (cats) => cats.length == 2)),
          predicate<Either<Failure, List<Category>>>((either) =>
              either.isRight() &&
              either.fold((_) => false, (cats) => cats.length == 1)),
          predicate<Either<Failure, List<Category>>>((either) =>
              either.isRight() &&
              either.fold((_) => false, (cats) => cats.isEmpty)),
        ]),
      );
    });
  });
}
