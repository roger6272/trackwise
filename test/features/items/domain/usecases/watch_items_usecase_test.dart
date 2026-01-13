import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/items/domain/entities/item.dart';
import 'package:trackwise/features/items/domain/usecases/get_items_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/watch_items_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late WatchItemsUseCase useCase;
  late MockItemRepository mockRepository;

  setUp(() {
    mockRepository = MockItemRepository();
    useCase = WatchItemsUseCase(mockRepository);
  });

  group('WatchItemsUseCase', () {
    const userId = 'user_123';

    test('should return stream of items from repository', () {
      // Arrange
      final stream = Stream.value(Right<Failure, List<Item>>(testItems));
      when(() => mockRepository.watchItems(any())).thenAnswer((_) => stream);

      // Act
      final result = useCase(GetItemsParams(userId));

      // Assert
      expect(result, stream);
      verify(() => mockRepository.watchItems(userId)).called(1);
    });

    test('should return stream with failure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Stream error');
      final stream = Stream.value(const Left<Failure, List<Item>>(failure));
      when(() => mockRepository.watchItems(any())).thenAnswer((_) => stream);

      // Act
      final result = useCase(GetItemsParams(userId));

      // Assert
      await expectLater(result, emits(const Left(failure)));
      verify(() => mockRepository.watchItems(userId)).called(1);
    });

    test('should emit multiple values from stream', () async {
      // Arrange
      final stream = Stream.fromIterable([
        Right<Failure, List<Item>>(testItems),
        Right<Failure, List<Item>>([testItem]),
        const Right<Failure, List<Item>>([]),
      ]);
      when(() => mockRepository.watchItems(any())).thenAnswer((_) => stream);

      // Act
      final result = useCase(GetItemsParams(userId));

      // Assert
      await expectLater(
        result,
        emitsInOrder([
          predicate<Either<Failure, List<Item>>>(
            (either) => either.isRight() && either.fold((_) => false, (items) => items.length == 2)
          ),
          predicate<Either<Failure, List<Item>>>(
            (either) => either.isRight() && either.fold((_) => false, (items) => items.length == 1)
          ),
          predicate<Either<Failure, List<Item>>>(
            (either) => either.isRight() && either.fold((_) => false, (items) => items.isEmpty)
          ),
        ]),
      );
    });
  });
}
