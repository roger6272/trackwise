import 'package:trackwise/features/events/domain/entities/event_log.dart';

/// Test fixtures for EventLog tests.

final testEventLog1 = EventLog(
  id: 'event_1',
  createdTime: DateTime(2024, 1, 15, 10, 30),
  itemId: 'item_123',
  eventName: 'increment',
  increment: 1,
  currentCount: 10,
  userId: 'user_123',
);

final testEventLog2 = EventLog(
  id: 'event_2',
  createdTime: DateTime(2024, 1, 15, 11, 0),
  itemId: 'item_123',
  eventName: 'increment',
  increment: 2,
  currentCount: 12,
  userId: 'user_123',
);

final testEventLog3 = EventLog(
  id: 'event_3',
  createdTime: DateTime(2024, 1, 16, 9, 0),
  itemId: 'item_123',
  eventName: 'decrement',
  increment: -1,
  currentCount: 11,
  userId: 'user_123',
);

final testEventLogSwitch = EventLog(
  id: 'event_switch',
  createdTime: DateTime(2024, 1, 16, 10, 0),
  itemId: 'item_456',
  eventName: 'switch',
  increment: 0,
  currentCount: 0,
  userId: 'user_123',
);

final testEventLogs = [testEventLog1, testEventLog2, testEventLog3];

final testEventLogsWithSwitch = [
  testEventLog1,
  testEventLog2,
  testEventLogSwitch,
];

const testUserId = 'user_123';
const testItemId = 'item_123';

final testStartDate = DateTime(2024, 1, 1);
final testEndDate = DateTime(2024, 1, 31);
