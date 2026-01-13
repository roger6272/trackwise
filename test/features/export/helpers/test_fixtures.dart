import 'package:trackwise/features/events/domain/entities/event_log.dart';
import 'package:trackwise/features/export/domain/entities/csv_export_config.dart';
import 'package:trackwise/features/export/domain/entities/send_email_params.dart';

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

/// Events spanning multiple weeks for weekly aggregation tests.
final testEventsMultipleWeeks = [
  // Week 1: Jan 8-14 (starts Monday Jan 8)
  EventLog(
    id: 'e1',
    createdTime: DateTime(2024, 1, 8, 10, 0),
    itemId: 'item_1',
    eventName: 'Coffee',
    increment: 2,
    currentCount: 2,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e2',
    createdTime: DateTime(2024, 1, 10, 10, 0),
    itemId: 'item_1',
    eventName: 'Coffee',
    increment: 3,
    currentCount: 5,
    userId: 'user_1',
  ),
  // Week 2: Jan 15-21 (starts Monday Jan 15)
  EventLog(
    id: 'e3',
    createdTime: DateTime(2024, 1, 15, 10, 0),
    itemId: 'item_1',
    eventName: 'Coffee',
    increment: 4,
    currentCount: 9,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e4',
    createdTime: DateTime(2024, 1, 18, 10, 0),
    itemId: 'item_1',
    eventName: 'Coffee',
    increment: 1,
    currentCount: 10,
    userId: 'user_1',
  ),
];

/// Events spanning multiple months for monthly aggregation tests.
final testEventsMultipleMonths = [
  EventLog(
    id: 'e1',
    createdTime: DateTime(2024, 1, 15, 10, 0),
    itemId: 'item_1',
    eventName: 'Coffee',
    increment: 5,
    currentCount: 5,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e2',
    createdTime: DateTime(2024, 1, 20, 10, 0),
    itemId: 'item_1',
    eventName: 'Coffee',
    increment: 3,
    currentCount: 8,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e3',
    createdTime: DateTime(2024, 2, 5, 10, 0),
    itemId: 'item_1',
    eventName: 'Coffee',
    increment: 7,
    currentCount: 15,
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

final testCSVConfigWeekly = CSVExportConfig(
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2024, 1, 31),
  aggregationLevel: ExportAggregationLevel.weekly,
);

final testCSVConfigMonthly = CSVExportConfig(
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2024, 2, 28),
  aggregationLevel: ExportAggregationLevel.monthly,
);

/// Default SendEmailParams for testing.
final testSendEmailParams = SendEmailParams(
  email: testEmail,
  startDate: testStartDate,
  endDate: testEndDate,
  aggregationLevel: ExportAggregationLevel.daily,
);

final testSendEmailParamsWithItem = SendEmailParams(
  email: testEmail,
  startDate: testStartDate,
  endDate: testEndDate,
  aggregationLevel: ExportAggregationLevel.daily,
  itemId: testItemId,
);
