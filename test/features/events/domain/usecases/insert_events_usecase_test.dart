import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/events/domain/entities/event_log.dart';
import 'package:traxelos/features/events/domain/usecases/insert_events_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late InsertEventsUseCase useCase;
  late MockEventLogRepository mockRepository;

  setUp(() {
    mockRepository = MockEventLogRepository();
    useCase = InsertEventsUseCase(mockRepository);
  });

  setUpAll(() {
    registerFallbackValue(<EventLog>[]);
  });

  group('InsertEventsUseCase', () {
    test('should insert events via repository when successful', () async {
      // Arrange
      when(() => mockRepository.insertEvents(any()))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(InsertEventsParams(testEventLogs));

      // Assert
      expect(result, const Right(null));
      verify(() => mockRepository.insertEvents(testEventLogs)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to insert events');
      when(() => mockRepository.insertEvents(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(InsertEventsParams(testEventLogs));

      // Assert
      expect(result, const Left(failure));
    });

    test('should filter out switch events before inserting', () async {
      // Arrange
      when(() => mockRepository.insertEvents(any()))
          .thenAnswer((_) async => const Right(null));

      // Act
      await useCase(InsertEventsParams(testEventLogsWithSwitch));

      // Assert - should only insert non-switch events
      verify(() => mockRepository.insertEvents(
            [testEventLog1, testEventLog2],
          )).called(1);
    });

    test('should return Right(null) when all events are switch events', () async {
      // Arrange
      final switchOnlyEvents = [testEventLogSwitch];

      // Act
      final result = await useCase(InsertEventsParams(switchOnlyEvents));

      // Assert - should not call repository
      expect(result, const Right(null));
      verifyNever(() => mockRepository.insertEvents(any()));
    });

    test('should handle empty events list', () async {
      // Act
      final result = await useCase(InsertEventsParams(const []));

      // Assert - should not call repository for empty list
      expect(result, const Right(null));
      verifyNever(() => mockRepository.insertEvents(any()));
    });
  });
}
