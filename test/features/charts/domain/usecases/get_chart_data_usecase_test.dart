import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/charts/domain/entities/chart_data.dart';
import 'package:trackwise/features/charts/domain/usecases/get_chart_data_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late GetChartDataUseCase useCase;
  late MockEventLogRepository mockRepository;
  late MockItemRepository mockItemRepository;

  setUp(() {
    mockRepository = MockEventLogRepository();
    mockItemRepository = MockItemRepository();
    useCase = GetChartDataUseCase(mockRepository, mockItemRepository);
  });

  group('GetChartDataUseCase', () {
    test('should aggregate events by day when aggregation is daily', () async {
      // Arrange
      when(() => mockRepository.getEventsByDateRange(any(), any()))
          .thenAnswer((_) async => Right(testEventsForAggregation));

      // Act
      final result = await useCase(GetChartDataParams(
        startDate: testStartDate,
        endDate: testEndDate,
        aggregationLevel: AggregationLevel.daily,
      ));

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not fail'),
        (chartData) {
          expect(chartData.aggregationLevel, AggregationLevel.daily);
          expect(chartData.dataPoints.length, 3); // 3 different days
          // Jan 15: 3 + 2 = 5
          expect(chartData.dataPoints[0].value, 5);
          // Jan 16: 10
          expect(chartData.dataPoints[1].value, 10);
          // Jan 17: 3
          expect(chartData.dataPoints[2].value, 3);
        },
      );
    });

    test('should return ServerFailure when repository fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to fetch events');
      when(() => mockRepository.getEventsByDateRange(any(), any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(GetChartDataParams(
        startDate: testStartDate,
        endDate: testEndDate,
      ));

      // Assert
      expect(result, const Left(failure));
    });

    test('should return empty chart data when no events', () async {
      // Arrange
      when(() => mockRepository.getEventsByDateRange(any(), any()))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(GetChartDataParams(
        startDate: testStartDate,
        endDate: testEndDate,
      ));

      // Assert
      result.fold(
        (failure) => fail('Should not fail'),
        (chartData) {
          expect(chartData.isEmpty, true);
          expect(chartData.dataPoints, isEmpty);
        },
      );
    });

    test('should use getEventsByItemAndDateRange when itemId is provided', () async {
      // Arrange
      when(() => mockItemRepository.getItem(any()))
          .thenAnswer((_) async => Right(testItem));
      when(() => mockRepository.getEventsByItemAndDateRange(any(), any(), any()))
          .thenAnswer((_) async => Right(testEventsForAggregation));

      // Act
      await useCase(GetChartDataParams(
        startDate: testStartDate,
        endDate: testEndDate,
        itemId: testItemId,
      ));

      // Assert
      verify(() => mockRepository.getEventsByItemAndDateRange(
        testItemId,
        testStartDate,
        testEndDate,
      )).called(1);
      verifyNever(() => mockRepository.getEventsByDateRange(any(), any()));
    });

    test('should include initialCount in chart data when itemId is provided', () async {
      // Arrange
      when(() => mockItemRepository.getItem(any()))
          .thenAnswer((_) async => Right(testItem));
      when(() => mockRepository.getEventsByItemAndDateRange(any(), any(), any()))
          .thenAnswer((_) async => Right(testEventsForAggregation));

      // Act
      final result = await useCase(GetChartDataParams(
        startDate: testStartDate,
        endDate: testEndDate,
        itemId: testItemId,
      ));

      // Assert
      result.fold(
        (failure) => fail('Should not fail'),
        (chartData) {
          expect(chartData.initialCount, testItem.initialCount);
        },
      );
    });

    test('should have initialCount 0 when no itemId is provided', () async {
      // Arrange
      when(() => mockRepository.getEventsByDateRange(any(), any()))
          .thenAnswer((_) async => Right(testEventsForAggregation));

      // Act
      final result = await useCase(GetChartDataParams(
        startDate: testStartDate,
        endDate: testEndDate,
      ));

      // Assert
      result.fold(
        (failure) => fail('Should not fail'),
        (chartData) {
          expect(chartData.initialCount, 0);
        },
      );
    });

    test('should sort data points by date ascending', () async {
      // Arrange
      when(() => mockRepository.getEventsByDateRange(any(), any()))
          .thenAnswer((_) async => Right(testEventsForAggregation));

      // Act
      final result = await useCase(GetChartDataParams(
        startDate: testStartDate,
        endDate: testEndDate,
      ));

      // Assert
      result.fold(
        (failure) => fail('Should not fail'),
        (chartData) {
          for (int i = 0; i < chartData.dataPoints.length - 1; i++) {
            expect(
              chartData.dataPoints[i].date.isBefore(chartData.dataPoints[i + 1].date),
              true,
            );
          }
        },
      );
    });
  });
}
