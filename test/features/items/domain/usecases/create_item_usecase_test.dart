import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/events/domain/entities/event_log.dart';
import 'package:traxelos/features/items/domain/entities/item.dart';
import 'package:traxelos/features/items/domain/usecases/create_item_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late CreateItemUseCase useCase;
  late MockItemRepository mockRepository;
  late MockEventLogRepository mockEventLogRepository;

  setUp(() {
    mockRepository = MockItemRepository();
    mockEventLogRepository = MockEventLogRepository();
    useCase = CreateItemUseCase(mockRepository, mockEventLogRepository);

    // Register fallback value for Item and EventLog list
    registerFallbackValue(testItem);
    registerFallbackValue(<EventLog>[]);
  });

  group('CreateItemUseCase', () {
    const userId = 'user_123';

    final validParams = CreateItemParams(
      name: 'Coffee',
      incrementBy: 1,
      reminder: ReminderType.target,
      reminderValue: 20,
      userId: userId,
    );

    test('should create item when all validations pass', () async {
      // Arrange
      when(() => mockRepository.createItem(any()))
          .thenAnswer((_) async => Right(testItem));
      when(() => mockEventLogRepository.insertEvents(any()))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(validParams);

      // Assert
      expect(result, isA<Right<Failure, Item>>());
      verify(() => mockRepository.createItem(any())).called(1);
      verify(() => mockEventLogRepository.insertEvents(any())).called(1);
    });

    test('should return ValidationFailure for empty name', () async {
      // Arrange
      final params = CreateItemParams(
        name: '',
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        userId: userId,
      );

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('name'));
      verifyNever(() => mockRepository.createItem(any()));
    });

    test('should return ValidationFailure for whitespace-only name', () async {
      // Arrange
      final params = CreateItemParams(
        name: '   ',
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        userId: userId,
      );

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      verifyNever(() => mockRepository.createItem(any()));
    });

    test('should return ValidationFailure for name > 30 chars', () async {
      // Arrange
      final params = CreateItemParams(
        name: 'a' * 31,
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        userId: userId,
      );

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('30'));
      verifyNever(() => mockRepository.createItem(any()));
    });

    test('should return ValidationFailure for incrementBy < 1', () async {
      // Arrange
      final params = CreateItemParams(
        name: 'Test',
        incrementBy: 0,
        reminder: ReminderType.none,
        reminderValue: 0,
        userId: userId,
      );

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('1'));
      verifyNever(() => mockRepository.createItem(any()));
    });

    test('should return ValidationFailure for incrementBy > 1000', () async {
      // Arrange
      final params = CreateItemParams(
        name: 'Test',
        incrementBy: 1001,
        reminder: ReminderType.none,
        reminderValue: 0,
        userId: userId,
      );

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('1000'));
      verifyNever(() => mockRepository.createItem(any()));
    });

    test('should return ValidationFailure for reminderValue < 0', () async {
      // Arrange
      final params = CreateItemParams(
        name: 'Test',
        incrementBy: 1,
        reminder: ReminderType.target,
        reminderValue: -1,
        userId: userId,
      );

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      verifyNever(() => mockRepository.createItem(any()));
    });

    test('should return ValidationFailure for reminderValue > 9999', () async {
      // Arrange
      final params = CreateItemParams(
        name: 'Test',
        incrementBy: 1,
        reminder: ReminderType.target,
        reminderValue: 10000,
        userId: userId,
      );

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      expect((result as Left).value.message, contains('9999'));
      verifyNever(() => mockRepository.createItem(any()));
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to create item');
      when(() => mockRepository.createItem(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(validParams);

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.createItem(any())).called(1);
      verifyNever(() => mockEventLogRepository.insertEvents(any()));
    });
  });

  group('CreateItemParams', () {
    test('should have correct props for Equatable', () {
      // Arrange
      const params = CreateItemParams(
        name: 'Coffee',
        incrementBy: 1,
        reminder: ReminderType.target,
        reminderValue: 20,
        userId: 'user_123',
      );

      // Act
      final props = params.props;

      // Assert
      expect(
        props,
        [
          'Coffee',
          0, // initialValue defaults to 0
          1,
          ReminderType.target,
          20,
          'user_123',
        ],
      );
    });

    test('should be equal when all properties are same', () {
      // Arrange
      const params1 = CreateItemParams(
        name: 'Coffee',
        incrementBy: 1,
        reminder: ReminderType.target,
        reminderValue: 20,
        userId: 'user_123',
      );

      const params2 = CreateItemParams(
        name: 'Coffee',
        incrementBy: 1,
        reminder: ReminderType.target,
        reminderValue: 20,
        userId: 'user_123',
      );

      // Act & Assert
      expect(params1, equals(params2));
      expect(params1.hashCode, equals(params2.hashCode));
    });
  });
}
