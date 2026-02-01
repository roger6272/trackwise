import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/events/domain/entities/event_log.dart';
import 'package:traxelos/features/events/domain/usecases/get_events_by_date_range_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late GetEventsByDateRangeUseCase useCase;
  late MockEventLogRepository mockRepository;

  setUp(() {
    mockRepository = MockEventLogRepository();
    useCase = GetEventsByDateRangeUseCase(mockRepository);
  });

  group('GetEventsByDateRangeUseCase', () {
    test('should get events from repository when successful', () async {
      // Arrange
      when(() => mockRepository.getEventsByDateRange(any(), any()))
          .thenAnswer((_) async => Right(testEventLogs));

      // Act
      final result = await useCase(GetEventsByDateRangeParams(
        startDate: testStartDate,
        endDate: testEndDate,
      ));

      // Assert
      expect(result, Right(testEventLogs));
      verify(() => mockRepository.getEventsByDateRange(
            testStartDate,
            testEndDate,
          )).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to fetch events');
      when(() => mockRepository.getEventsByDateRange(any(), any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(GetEventsByDateRangeParams(
        startDate: testStartDate,
        endDate: testEndDate,
      ));

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.getEventsByDateRange(
            testStartDate,
            testEndDate,
          )).called(1);
    });

    test('should return empty list when no events in range', () async {
      // Arrange
      when(() => mockRepository.getEventsByDateRange(any(), any()))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(GetEventsByDateRangeParams(
        startDate: testStartDate,
        endDate: testEndDate,
      ));

      // Assert
      expect(result, Right<Failure, List<EventLog>>(const []));
    });

    test('should call repository with correct date range', () async {
      // Arrange
      final customStart = DateTime(2024, 2, 1);
      final customEnd = DateTime(2024, 2, 28);
      when(() => mockRepository.getEventsByDateRange(any(), any()))
          .thenAnswer((_) async => Right(testEventLogs));

      // Act
      await useCase(GetEventsByDateRangeParams(
        startDate: customStart,
        endDate: customEnd,
      ));

      // Assert
      verify(() => mockRepository.getEventsByDateRange(
            customStart,
            customEnd,
          )).called(1);
    });
  });
}
