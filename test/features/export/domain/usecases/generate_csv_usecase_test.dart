import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/export/domain/entities/csv_export_config.dart';
import 'package:trackwise/features/export/domain/usecases/generate_csv_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late GenerateCSVUseCase useCase;
  late MockEventLogRepository mockRepository;

  setUp(() {
    mockRepository = MockEventLogRepository();
    useCase = GenerateCSVUseCase(mockRepository);
  });

  group('GenerateCSVUseCase', () {
    group('raw aggregation', () {
      test('should generate CSV with raw events', () async {
        // Arrange
        when(() => mockRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsForCSV));

        // Act
        final result = await useCase(testCSVConfigRaw);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines[0], 'Item Name,Date,Event Count');
            expect(lines.length, 5); // Header + 4 events
            expect(lines[1], contains('Coffee'));
            expect(lines[1], contains('2024-01-15'));
          },
        );
      });
    });

    group('daily aggregation', () {
      test('should aggregate events by day', () async {
        // Arrange
        when(() => mockRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsForCSV));

        // Act
        final result = await useCase(testCSVConfig);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines[0], 'Item Name,Date,Event Count');
            // Coffee: Jan 15 (3+2=5), Jan 16 (4)
            // Tea: Jan 16 (1)
            // = 3 data rows + header
            expect(lines.length, 4);

            // Check Coffee Jan 15 aggregation (3+2=5)
            expect(lines.any((l) => l.contains('Coffee') && l.contains('2024-01-15') && l.contains('5')), true);
            // Check Coffee Jan 16 (4)
            expect(lines.any((l) => l.contains('Coffee') && l.contains('2024-01-16') && l.contains('4')), true);
            // Check Tea Jan 16 (1)
            expect(lines.any((l) => l.contains('Tea') && l.contains('2024-01-16') && l.contains('1')), true);
          },
        );
      });
    });

    group('weekly aggregation', () {
      test('should aggregate events by week', () async {
        // Arrange
        when(() => mockRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsMultipleWeeks));

        // Act
        final result = await useCase(testCSVConfigWeekly);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines[0], 'Item Name,Date,Event Count');
            // Week 1: 2+3=5
            // Week 2: 4+1=5
            expect(lines.length, 3); // Header + 2 weeks

            // Check Week 1 (starts Monday Jan 8): 2+3=5
            expect(lines.any((l) => l.contains('Coffee') && l.contains('2024-01-08') && l.contains('5')), true);
            // Check Week 2 (starts Monday Jan 15): 4+1=5
            expect(lines.any((l) => l.contains('Coffee') && l.contains('2024-01-15') && l.contains('5')), true);
          },
        );
      });
    });

    group('monthly aggregation', () {
      test('should aggregate events by month', () async {
        // Arrange
        when(() => mockRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsMultipleMonths));

        // Act
        final result = await useCase(testCSVConfigMonthly);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines[0], 'Item Name,Date,Event Count');
            // January: 5+3=8
            // February: 7
            expect(lines.length, 3); // Header + 2 months

            // Check January: 5+3=8
            expect(lines.any((l) => l.contains('Coffee') && l.contains('2024-01-01') && l.contains('8')), true);
            // Check February: 7
            expect(lines.any((l) => l.contains('Coffee') && l.contains('2024-02-01') && l.contains('7')), true);
          },
        );
      });
    });

    group('special characters', () {
      test('should escape commas in item names', () async {
        // Arrange
        when(() => mockRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsWithSpecialChars));

        // Act
        final result = await useCase(testCSVConfigRaw);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            // Item with comma should be wrapped in quotes
            expect(csv, contains('"Coffee, Tea"'));
          },
        );
      });

      test('should escape quotes in item names', () async {
        // Arrange
        when(() => mockRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsWithSpecialChars));

        // Act
        final result = await useCase(testCSVConfigRaw);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            // Item with quotes should have quotes doubled and wrapped
            expect(csv, contains('"Item ""Special"""'));
          },
        );
      });
    });

    group('empty data', () {
      test('should return header only when no events', () async {
        // Arrange
        when(() => mockRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => const Right([]));

        // Act
        final result = await useCase(testCSVConfig);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines.length, 1);
            expect(lines[0], 'Item Name,Date,Event Count');
          },
        );
      });
    });

    group('error handling', () {
      test('should return failure when repository fails', () async {
        // Arrange
        const failure = ServerFailure('Failed to fetch events');
        when(() => mockRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => const Left(failure));

        // Act
        final result = await useCase(testCSVConfig);

        // Assert
        expect(result, const Left(failure));
      });
    });

    group('item filtering', () {
      test('should use getEventsByItem when itemId is provided', () async {
        // Arrange
        final config = CSVExportConfig(
          startDate: testStartDate,
          endDate: testEndDate,
          aggregationLevel: ExportAggregationLevel.daily,
          itemId: testItemId,
        );
        when(() => mockRepository.getEventsByItem(any()))
            .thenAnswer((_) async => Right(testEventsForCSV));

        // Act
        await useCase(config);

        // Assert
        verify(() => mockRepository.getEventsByItem(testItemId)).called(1);
        verifyNever(() => mockRepository.getEventsByDateRange(any(), any()));
      });
    });
  });

  group('CSVExportConfig', () {
    test('should generate correct filename', () {
      final config = CSVExportConfig(
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 31),
        aggregationLevel: ExportAggregationLevel.daily,
      );

      expect(config.filename, 'tally_export_2024-01-01_to_2024-01-31_daily.csv');
    });

    test('should generate filename with weekly aggregation', () {
      final config = CSVExportConfig(
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 31),
        aggregationLevel: ExportAggregationLevel.weekly,
      );

      expect(config.filename, 'tally_export_2024-01-01_to_2024-01-31_weekly.csv');
    });

    test('should generate filename with monthly aggregation', () {
      final config = CSVExportConfig(
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
        aggregationLevel: ExportAggregationLevel.monthly,
      );

      expect(config.filename, 'tally_export_2024-01-01_to_2024-12-31_monthly.csv');
    });
  });
}
