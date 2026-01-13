import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/items/domain/usecases/delete_item_usecase.dart';

import '../../helpers/test_helper.dart';

void main() {
  late DeleteItemUseCase useCase;
  late MockItemRepository mockRepository;

  setUp(() {
    mockRepository = MockItemRepository();
    useCase = DeleteItemUseCase(mockRepository);
  });

  group('DeleteItemUseCase', () {
    const itemId = 'test_item_1';
    final params = DeleteItemParams(itemId);

    test('should delete item successfully', () async {
      // Arrange
      when(() => mockRepository.deleteItem(any()))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Right(null));
      verify(() => mockRepository.deleteItem(itemId)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to delete item');
      when(() => mockRepository.deleteItem(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.deleteItem(itemId)).called(1);
    });

    test('should verify repository called with correct itemId', () async {
      // Arrange
      const differentItemId = 'different_item_id';
      when(() => mockRepository.deleteItem(any()))
          .thenAnswer((_) async => const Right(null));

      // Act
      await useCase(DeleteItemParams(differentItemId));

      // Assert
      verify(() => mockRepository.deleteItem(differentItemId)).called(1);
    });
  });

  group('DeleteItemParams', () {
    test('should have correct props for Equatable', () {
      // Arrange
      const params = DeleteItemParams('item_123');

      // Act
      final props = params.props;

      // Assert
      expect(props, ['item_123']);
    });
  });
}
