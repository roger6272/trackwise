import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/events/domain/entities/event_log.dart';
import 'package:trackwise/features/events/domain/usecases/get_events_by_item_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late GetEventsByItemUseCase useCase;
  late MockEventLogRepository mockRepository;

  setUp(() {
    mockRepository = MockEventLogRepository();
    useCase = GetEventsByItemUseCase(mockRepository);
  });

  group('GetEventsByItemUseCase', () {
    test('should get events for item from repository when successful', () async {
      // Arrange
      when(() => mockRepository.getEventsByItem(any()))
          .thenAnswer((_) async => Right(testEventLogs));

      // Act
      final result = await useCase(GetEventsByItemParams(testItemId));

      // Assert
      expect(result, Right(testEventLogs));
      verify(() => mockRepository.getEventsByItem(testItemId)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to fetch events');
      when(() => mockRepository.getEventsByItem(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(GetEventsByItemParams(testItemId));

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.getEventsByItem(testItemId)).called(1);
    });

    test('should return empty list when no events for item', () async {
      // Arrange
      when(() => mockRepository.getEventsByItem(any()))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(GetEventsByItemParams(testItemId));

      // Assert
      expect(result, Right<Failure, List<EventLog>>(const []));
    });

    test('should call repository with correct itemId', () async {
      // Arrange
      const differentItemId = 'item_456';
      when(() => mockRepository.getEventsByItem(any()))
          .thenAnswer((_) async => Right(testEventLogs));

      // Act
      await useCase(GetEventsByItemParams(differentItemId));

      // Assert
      verify(() => mockRepository.getEventsByItem(differentItemId)).called(1);
    });
  });
}
