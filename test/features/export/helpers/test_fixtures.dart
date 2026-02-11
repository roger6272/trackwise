import 'package:traxelos/features/events/domain/entities/event_log.dart';
import 'package:traxelos/features/export/domain/entities/csv_export_config.dart';
import 'package:traxelos/features/export/domain/entities/send_email_params.dart';

/// Test fixtures for Export tests.

final testStartDate = DateTime(2024, 1, 1);
final testEndDate = DateTime(2024, 1, 31);
const testItemId = 'item_1';
const testEmail = 'test@example.com';

/// Test CSV content for email tests.
const testCSVContent = '''Item Name,Date,Event Count
Coffee,2024-01-15,5
Coffee,2024-01-16,4
Tea,2024-01-16,1
''';

/// Test event logs for CSV generation.
final testEventsForCSV = [
  EventLog(
    id: 'e1',
    createdTime: DateTime(2024, 1, 15, 10, 0),
    itemId: 'item_1',
    eventName: 'Coffee',
    increment: 3,
    currentCount: 3,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e2',
    createdTime: DateTime(2024, 1, 15, 14, 0),
    itemId: 'item_1',
    eventName: 'Coffee',
    increment: 2,
    currentCount: 5,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e3',
    createdTime: DateTime(2024, 1, 16, 9, 0),
    itemId: 'item_1',
    eventName: 'Coffee',
    increment: 4,
    currentCount: 9,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e4',
    createdTime: DateTime(2024, 1, 16, 15, 0),
    itemId: 'item_2',
    eventName: 'Tea',
    increment: 1,
    currentCount: 1,
    userId: 'user_1',
  ),
];

/// Events with special characters for CSV escaping tests.
final testEventsWithSpecialChars = [
  EventLog(
    id: 'e1',
    createdTime: DateTime(2024, 1, 15, 10, 0),
    itemId: 'item_1',
    eventName: 'Coffee, Tea',
    increment: 3,
    currentCount: 3,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e2',
    createdTime: DateTime(2024, 1, 15, 14, 0),
    itemId: 'item_2',
    eventName: 'Item "Special"',
    increment: 2,
    currentCount: 2,
    userId: 'user_1',
  ),
];

/// Events with multiple cycles for byCycle aggregation tests.
final testEventsMultiCycle = [
  // item_1 cycle 0: 3 + 2 = 5
  EventLog(
    id: 'mc1',
    createdTime: DateTime(2024, 1, 10, 10, 0),
    itemId: 'item_1',
    eventName: 'increment',
    increment: 3,
    currentCount: 3,
    resetNumber: 0,
    userId: 'user_1',
  ),
  EventLog(
    id: 'mc2',
    createdTime: DateTime(2024, 1, 11, 10, 0),
    itemId: 'item_1',
    eventName: 'increment',
    increment: 2,
    currentCount: 5,
    resetNumber: 0,
    userId: 'user_1',
  ),
  // item_1 reset event (should be excluded from count)
  EventLog(
    id: 'mc3',
    createdTime: DateTime(2024, 1, 12, 10, 0),
    itemId: 'item_1',
    eventName: 'reset',
    increment: 0,
    currentCount: 0,
    resetNumber: 1,
    userId: 'user_1',
  ),
  // item_1 cycle 1: 4
  EventLog(
    id: 'mc4',
    createdTime: DateTime(2024, 1, 13, 10, 0),
    itemId: 'item_1',
    eventName: 'increment',
    increment: 4,
    currentCount: 4,
    resetNumber: 1,
    userId: 'user_1',
  ),
  // item_2 cycle 0: 1
  EventLog(
    id: 'mc5',
    createdTime: DateTime(2024, 1, 14, 10, 0),
    itemId: 'item_2',
    eventName: 'increment',
    increment: 1,
    currentCount: 1,
    resetNumber: 0,
    userId: 'user_1',
  ),
];

/// Events with reset events for daily aggregation filtering test.
final testEventsWithResets = [
  EventLog(
    id: 'r1',
    createdTime: DateTime(2024, 1, 15, 10, 0),
    itemId: 'item_1',
    eventName: 'increment',
    increment: 3,
    currentCount: 3,
    userId: 'user_1',
  ),
  EventLog(
    id: 'r2',
    createdTime: DateTime(2024, 1, 15, 12, 0),
    itemId: 'item_1',
    eventName: 'reset',
    increment: 0,
    currentCount: 0,
    resetNumber: 1,
    userId: 'user_1',
  ),
  EventLog(
    id: 'r3',
    createdTime: DateTime(2024, 1, 15, 14, 0),
    itemId: 'item_1',
    eventName: 'created',
    increment: 0,
    currentCount: 0,
    userId: 'user_1',
  ),
  EventLog(
    id: 'r4',
    createdTime: DateTime(2024, 1, 15, 16, 0),
    itemId: 'item_1',
    eventName: 'increment',
    increment: 2,
    currentCount: 2,
    resetNumber: 1,
    userId: 'user_1',
  ),
];

/// Default CSV export config for testing.
final testCSVConfig = CSVExportConfig(
  startDate: testStartDate,
  endDate: testEndDate,
  aggregationLevel: ExportAggregationLevel.daily,
);

final testCSVConfigRaw = CSVExportConfig(
  startDate: testStartDate,
  endDate: testEndDate,
  aggregationLevel: ExportAggregationLevel.raw,
);

final testCSVConfigByCycle = CSVExportConfig(
  startDate: testStartDate,
  endDate: testEndDate,
  aggregationLevel: ExportAggregationLevel.byCycle,
);

final testCSVConfigByCycleLatest = CSVExportConfig(
  startDate: testStartDate,
  endDate: testEndDate,
  aggregationLevel: ExportAggregationLevel.byCycle,
  latestCycleOnly: true,
);

/// Default SendEmailParams for testing.
final testSendEmailParams = SendEmailParams(
  email: testEmail,
  startDate: testStartDate,
  endDate: testEndDate,
  aggregationLevel: ExportAggregationLevel.daily,
);

final testSendEmailParamsWithItems = SendEmailParams(
  email: testEmail,
  startDate: testStartDate,
  endDate: testEndDate,
  aggregationLevel: ExportAggregationLevel.daily,
  itemIds: [testItemId],
);

final testCSVConfigWithItems = CSVExportConfig(
  startDate: testStartDate,
  endDate: testEndDate,
  aggregationLevel: ExportAggregationLevel.daily,
  itemIds: [testItemId],
);
