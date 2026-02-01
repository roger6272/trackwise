import 'package:traxelos/features/charts/domain/entities/chart_data.dart';
import 'package:traxelos/features/charts/domain/entities/chart_data_point.dart';
import 'package:traxelos/features/events/domain/entities/event_log.dart';
import 'package:traxelos/features/items/domain/entities/item.dart';

/// Test fixtures for Charts tests.

// Chart data points
final testDataPoint1 = ChartDataPoint(
  date: DateTime(2024, 1, 15),
  value: 5,
);

final testDataPoint2 = ChartDataPoint(
  date: DateTime(2024, 1, 16),
  value: 10,
);

final testDataPoint3 = ChartDataPoint(
  date: DateTime(2024, 1, 17),
  value: 3,
);

final testDataPoints = [testDataPoint1, testDataPoint2, testDataPoint3];

// Chart data
final testChartDataDaily = ChartData(
  dataPoints: testDataPoints,
  aggregationLevel: AggregationLevel.daily,
);

final testChartDataWeekly = ChartData(
  dataPoints: testDataPoints,
  aggregationLevel: AggregationLevel.weekly,
);

final testChartDataMonthly = ChartData(
  dataPoints: testDataPoints,
  aggregationLevel: AggregationLevel.monthly,
);

final emptyChartData = ChartData(
  dataPoints: const [],
  aggregationLevel: AggregationLevel.daily,
);

// Cumulative chart data
final testCumulativeDataPoints = [
  ChartDataPoint(date: DateTime(2024, 1, 15), value: 5),
  ChartDataPoint(date: DateTime(2024, 1, 16), value: 15), // 5 + 10
  ChartDataPoint(date: DateTime(2024, 1, 17), value: 18), // 15 + 3
];

final testCumulativeChartData = ChartData(
  dataPoints: testCumulativeDataPoints,
  aggregationLevel: AggregationLevel.daily,
);

final testCumulativeChartDataWeekly = ChartData(
  dataPoints: testCumulativeDataPoints,
  aggregationLevel: AggregationLevel.weekly,
);

// Event logs for aggregation tests
final testEventsForAggregation = [
  EventLog(
    id: 'e1',
    createdTime: DateTime(2024, 1, 15, 10, 0),
    itemId: 'item_1',
    eventName: 'increment',
    increment: 3,
    currentCount: 3,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e2',
    createdTime: DateTime(2024, 1, 15, 14, 0),
    itemId: 'item_1',
    eventName: 'increment',
    increment: 2,
    currentCount: 5,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e3',
    createdTime: DateTime(2024, 1, 16, 9, 0),
    itemId: 'item_1',
    eventName: 'increment',
    increment: 10,
    currentCount: 15,
    userId: 'user_1',
  ),
  EventLog(
    id: 'e4',
    createdTime: DateTime(2024, 1, 17, 11, 0),
    itemId: 'item_1',
    eventName: 'increment',
    increment: 3,
    currentCount: 18,
    userId: 'user_1',
  ),
];

final testStartDate = DateTime(2024, 1, 1);
final testEndDate = DateTime(2024, 1, 31);
const testItemId = 'item_1';

// Test Item for cumulative chart tests
final testItem = Item(
  id: testItemId,
  name: 'Test Item',
  count: 18,
  todayCount: 3,
  incrementBy: 1,
  reminder: ReminderType.none,
  reminderValue: 0,
  lastUpdated: DateTime(2024, 1, 17),
  userId: 'user_1',
  initialCount: 10, // Initial count for chart tests
);

final testItemNoInitialCount = Item(
  id: testItemId,
  name: 'Test Item',
  count: 18,
  todayCount: 3,
  incrementBy: 1,
  reminder: ReminderType.none,
  reminderValue: 0,
  lastUpdated: DateTime(2024, 1, 17),
  userId: 'user_1',
  initialCount: 0,
);
