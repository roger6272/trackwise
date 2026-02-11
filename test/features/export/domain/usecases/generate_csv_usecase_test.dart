import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/export/domain/entities/csv_export_config.dart';
import 'package:traxelos/features/export/domain/usecases/generate_csv_usecase.dart';
import 'package:traxelos/features/items/domain/entities/item.dart' show Item, ReminderType;

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late GenerateCSVUseCase useCase;
  late MockEventLogRepository mockEventRepository;
  late MockItemRepository mockItemRepository;
  late MockCategoryRepository mockCategoryRepository;

  setUp(() {
    mockEventRepository = MockEventLogRepository();
    mockItemRepository = MockItemRepository();
    mockCategoryRepository = MockCategoryRepository();
    useCase = GenerateCSVUseCase(
      mockEventRepository,
      mockItemRepository,
      mockCategoryRepository,
    );
  });

  // Helper to set up item and category mocks
  void setupItemAndCategoryMocks({Map<String, String>? cycleNames, Map<String, String>? cycleNotes}) {
    when(() => mockItemRepository.getItems(any())).thenAnswer(
      (_) async => Right([
        Item(
          id: 'item_1',
          name: 'Coffee',
          categoryId: 'cat_1',
          userId: 'user_1',
          count: 0,
          todayCount: 0,
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          lastUpdated: DateTime.now(),
          order: 0,
          cycleNames: cycleNames ?? const {},
          cycleNotes: cycleNotes ?? const {},
        ),
        Item(
          id: 'item_2',
          name: 'Tea',
          categoryId: 'cat_2',
          userId: 'user_1',
          count: 0,
          todayCount: 0,
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          lastUpdated: DateTime.now(),
          order: 1,
        ),
      ]),
    );
    when(() => mockCategoryRepository.getCategories(any())).thenAnswer(
      (_) async => Right([
        Category(
          id: 'cat_1',
          name: 'Drinks',
          userId: 'user_1',
          order: 0,
          createdAt: DateTime.now(),
          lastUpdated: DateTime.now(),
        ),
        Category(
          id: 'cat_2',
          name: 'Beverages',
          userId: 'user_1',
          order: 1,
          createdAt: DateTime.now(),
          lastUpdated: DateTime.now(),
        ),
      ]),
    );
  }

  group('GenerateCSVUseCase', () {
    group('raw aggregation', () {
      test('should generate CSV with raw events', () async {
        // Arrange
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsForCSV));
        setupItemAndCategoryMocks();

        // Act
        final result = await useCase(testCSVConfigRaw);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines[0], 'Item Name,Category,Event Type,Cycle,Cycle Note,Timestamp,Event Count'); // Raw uses Timestamp
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
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsForCSV));
        setupItemAndCategoryMocks();

        // Act
        final result = await useCase(testCSVConfig);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines[0], 'Item Name,Category,Event Type,Date,Event Count');
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

      test('should exclude reset and created events from daily aggregation', () async {
        // Arrange
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsWithResets));
        setupItemAndCategoryMocks();

        // Act
        final result = await useCase(testCSVConfig);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            // Only increment events should be aggregated: 3 + 2 = 5 total
            // reset and created should be excluded
            expect(lines.any((l) => l.contains('reset')), false);
            expect(lines.any((l) => l.contains('created')), false);
            // Should have header + aggregated increment rows
            expect(lines.length, greaterThan(1));
          },
        );
      });
    });

    group('byCycle aggregation', () {
      test('should aggregate events by cycle', () async {
        // Arrange
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsMultiCycle));
        setupItemAndCategoryMocks(
          cycleNames: {'0': 'First batch', '1': 'Second batch'},
          cycleNotes: {'0': 'Note 0', '1': 'Note 1'},
        );

        // Act
        final result = await useCase(testCSVConfigByCycle);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines[0], 'Item Name,Category,Cycle,Cycle Name,Cycle Note,Total Count');

            // Coffee cycle 1 (resetNumber 0): 3 + 2 = 5
            expect(lines.any((l) => l.contains('Coffee') && l.contains(',1,') && l.contains(',5')), true);
            // Coffee cycle 2 (resetNumber 1): 4
            expect(lines.any((l) => l.contains('Coffee') && l.contains(',2,') && l.contains(',4')), true);
            // Tea cycle 1 (resetNumber 0): 1
            expect(lines.any((l) => l.contains('Tea') && l.contains(',1,') && l.contains(',1')), true);

            // Should have header + 3 data rows (Coffee cycle 1, Coffee cycle 2, Tea cycle 1)
            expect(lines.length, 4);
          },
        );
      });

      test('should include cycle names and notes', () async {
        // Arrange
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsMultiCycle));
        setupItemAndCategoryMocks(
          cycleNames: {'0': 'First batch', '1': 'Second batch'},
          cycleNotes: {'0': 'Note 0', '1': 'Note 1'},
        );

        // Act
        final result = await useCase(testCSVConfigByCycle);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            expect(csv, contains('First batch'));
            expect(csv, contains('Second batch'));
            expect(csv, contains('Note 0'));
            expect(csv, contains('Note 1'));
          },
        );
      });

      test('should include cycles with names/notes but no events', () async {
        // Arrange: events only go up to resetNumber 1, but cycleNames has key "2"
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsMultiCycle));
        setupItemAndCategoryMocks(
          cycleNames: {'0': 'First', '1': 'Second', '2': 'Third (no events)'},
          cycleNotes: {'2': 'Note for empty cycle'},
        );

        // Act
        final result = await useCase(testCSVConfigByCycle);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            // Coffee should have 3 cycles: 0, 1, 2 (even though 2 has no events)
            expect(csv, contains('Third (no events)'));
            expect(csv, contains('Note for empty cycle'));
            // Cycle 3 (resetNumber 2) should appear with 0 count
            expect(lines.any((l) => l.contains('Coffee') && l.contains(',3,') && l.contains(',0')), true);
          },
        );
      });

      test('should filter to latest cycle only when latestCycleOnly is true', () async {
        // Arrange
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsMultiCycle));
        setupItemAndCategoryMocks();

        // Act
        final result = await useCase(testCSVConfigByCycleLatest);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines[0], 'Item Name,Category,Cycle,Cycle Name,Cycle Note,Total Count');

            // item_1 latest cycle is resetNumber 1: 4
            // item_2 latest cycle is resetNumber 0: 1
            // Only 2 data rows + header
            expect(lines.length, 3);
            // Coffee cycle 2 (resetNumber 1): 4
            expect(lines.any((l) => l.contains('Coffee') && l.contains(',4')), true);
            // Tea cycle 1 (resetNumber 0): 1
            expect(lines.any((l) => l.contains('Tea') && l.contains(',1')), true);
          },
        );
      });
    });

    group('special characters', () {
      test('should escape commas in item names', () async {
        // Arrange
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsWithSpecialChars));
        setupItemAndCategoryMocks();

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
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsWithSpecialChars));
        setupItemAndCategoryMocks();

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
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
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
            expect(lines[0], 'Item Name,Category,Event Type,Date,Event Count');
          },
        );
      });

      test('should return byCycle header when no events', () async {
        // Arrange
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => const Right([]));

        // Act
        final result = await useCase(testCSVConfigByCycle);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines.length, 1);
            expect(lines[0], 'Item Name,Category,Cycle,Cycle Name,Cycle Note,Total Count');
          },
        );
      });
    });

    group('error handling', () {
      test('should return failure when repository fails', () async {
        // Arrange
        const failure = ServerFailure('Failed to fetch events');
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => const Left(failure));

        // Act
        final result = await useCase(testCSVConfig);

        // Assert
        expect(result, const Left(failure));
      });
    });

    group('item filtering', () {
      test('should always use getEventsByDateRange and filter by itemIds', () async {
        // Arrange
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsForCSV));
        setupItemAndCategoryMocks();

        // Act
        final result = await useCase(testCSVConfigWithItems);

        // Assert
        verify(() => mockEventRepository.getEventsByDateRange(any(), any())).called(1);
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            // Only item_1 (Coffee) events should be included, not item_2 (Tea)
            expect(lines.any((l) => l.contains('Tea')), false);
            expect(lines.any((l) => l.contains('Coffee')), true);
          },
        );
      });

      test('should return all items when itemIds is null', () async {
        // Arrange
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsForCSV));
        setupItemAndCategoryMocks();

        // Act
        final result = await useCase(testCSVConfig);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            // Both Coffee and Tea should be included
            expect(lines.any((l) => l.contains('Coffee')), true);
            expect(lines.any((l) => l.contains('Tea')), true);
          },
        );
      });

      test('should filter multiple itemIds', () async {
        // Arrange
        final config = CSVExportConfig(
          startDate: testStartDate,
          endDate: testEndDate,
          aggregationLevel: ExportAggregationLevel.daily,
          itemIds: ['item_1', 'item_2'],
        );
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(testEventsForCSV));
        setupItemAndCategoryMocks();

        // Act
        final result = await useCase(config);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (csv) {
            final lines = csv.trim().split('\n');
            expect(lines.any((l) => l.contains('Coffee')), true);
            expect(lines.any((l) => l.contains('Tea')), true);
          },
        );
      });
    });

    group('userId validation', () {
      test('should return ValidationFailure when userId is empty', () async {
        // Arrange
        final eventsWithEmptyUserId = [
          testEventsForCSV.first.copyWith(userId: ''),
        ];
        when(() => mockEventRepository.getEventsByDateRange(any(), any()))
            .thenAnswer((_) async => Right(eventsWithEmptyUserId));

        // Act
        final result = await useCase(testCSVConfig);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should fail'),
        );
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

    test('should generate filename for byCycle', () {
      final config = CSVExportConfig(
        startDate: DateTime(2020),
        endDate: DateTime(2024, 1, 31),
        aggregationLevel: ExportAggregationLevel.byCycle,
      );

      expect(config.filename, 'tally_export_by_cycle.csv');
    });

    test('should generate filename for byCycle latest cycle', () {
      final config = CSVExportConfig(
        startDate: DateTime(2020),
        endDate: DateTime(2024, 1, 31),
        aggregationLevel: ExportAggregationLevel.byCycle,
        latestCycleOnly: true,
      );

      expect(config.filename, 'tally_export_latest_cycle_by_cycle.csv');
    });
  });
}
