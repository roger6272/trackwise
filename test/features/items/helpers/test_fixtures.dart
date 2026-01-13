import 'package:trackwise/features/items/domain/entities/item.dart';
import 'package:trackwise/features/items/data/models/item_model.dart';

final testDateTime = DateTime(2026, 1, 4);

final testItem = Item(
  id: 'test_item_1',
  name: 'Coffee',
  count: 10,
  todayCount: 5,
  incrementBy: 1,
  reminder: ReminderType.target,
  reminderValue: 20,
  lastResetTime: testDateTime,
  lastUpdated: testDateTime,
  userId: 'user_123',
);

final testItem2 = Item(
  id: 'test_item_2',
  name: 'Water',
  count: 8,
  todayCount: 3,
  incrementBy: 1,
  reminder: ReminderType.interval,
  reminderValue: 5,
  lastResetTime: testDateTime,
  lastUpdated: testDateTime,
  userId: 'user_123',
);

final testItemModel = ItemModel(
  id: 'test_item_1',
  name: 'Coffee',
  count: 10,
  todayCount: 5,
  incrementBy: 1,
  reminder: ReminderType.target,
  reminderValue: 20,
  lastResetTime: testDateTime,
  lastUpdated: testDateTime,
  userId: 'user_123',
);

final testItemModel2 = ItemModel(
  id: 'test_item_2',
  name: 'Water',
  count: 8,
  todayCount: 3,
  incrementBy: 1,
  reminder: ReminderType.interval,
  reminderValue: 5,
  lastResetTime: testDateTime,
  lastUpdated: testDateTime,
  userId: 'user_123',
);

final testItems = [testItem, testItem2];
final testItemModels = [testItemModel, testItemModel2];
