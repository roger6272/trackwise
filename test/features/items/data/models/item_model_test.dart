import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/features/items/domain/entities/item.dart';
import 'package:trackwise/features/items/data/models/item_model.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  group('ItemModel', () {
    test('should be a subclass of Item entity', () {
      // Assert
      expect(testItemModel, isA<Item>());
    });

    test('should convert to Firestore map correctly', () {
      // Act
      final result = testItemModel.toFirestore();

      // Assert
      expect(result['item_name'], 'Coffee');
      expect(result['count'], 10);
      expect(result['todaycount'], 5);
      expect(result['increment_by'], 1);
      expect(result['reminder'], 'TARGET');
      expect(result['reminder_value'], 20);
      expect(result['user_id'], 'user_123');
      expect(result['lastResetTime'], isA<int>());
      expect(result['lastUpdated'], isA<int>());
      expect(result['lastResetTime'], testDateTime.millisecondsSinceEpoch);
      expect(result['lastUpdated'], testDateTime.millisecondsSinceEpoch);
    });

    test('should convert from Firestore document correctly', () {
      // Arrange
      final map = {
        'item_name': 'Coffee',
        'count': 10,
        'todaycount': 5,
        'increment_by': 1,
        'reminder': 'TARGET',
        'reminder_value': 20,
        'lastResetTime': testDateTime.millisecondsSinceEpoch,
        'lastUpdated': testDateTime.millisecondsSinceEpoch,
        'user_id': 'user_123',
      };

      final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDoc.id).thenReturn('test_item_1');
      when(() => mockDoc.data()).thenReturn(map);

      // Act
      final result = ItemModel.fromFirestore(mockDoc);

      // Assert
      expect(result.id, 'test_item_1');
      expect(result.name, 'Coffee');
      expect(result.count, 10);
      expect(result.todayCount, 5);
      expect(result.incrementBy, 1);
      expect(result.reminder, ReminderType.target);
      expect(result.reminderValue, 20);
      expect(result.userId, 'user_123');
    });

    test('should handle all enum conversions correctly', () {
      // Arrange & Act & Assert
      final tests = [
        ('NONE', ReminderType.none),
        ('TARGET', ReminderType.target),
        ('INTERVAL', ReminderType.interval),
        ('EVERY_TIME', ReminderType.none), // Legacy value maps to none
      ];

      for (final test in tests) {
        final map = {
          'item_name': 'Test',
          'reminder': test.$1,
          'user_id': 'user_123',
        };

        final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.id).thenReturn('test_id');
        when(() => mockDoc.data()).thenReturn(map);

        final result = ItemModel.fromFirestore(mockDoc);
        expect(result.reminder, test.$2);
      }
    });

    test('should handle DateTime conversion to milliseconds', () {
      // Arrange
      final specificDateTime = DateTime(2026, 3, 15, 10, 30, 45);
      final model = ItemModel(
        id: 'test',
        name: 'Test',
        count: 0,
        todayCount: 0,
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        lastResetTime: specificDateTime,
        lastUpdated: specificDateTime,
        userId: 'user',
      );

      // Act
      final result = model.toFirestore();

      // Assert
      expect(result['lastResetTime'], specificDateTime.millisecondsSinceEpoch);
      expect(result['lastUpdated'], specificDateTime.millisecondsSinceEpoch);
    });

    test('should handle missing fields with defaults', () {
      // Arrange
      final map = {
        'item_name': 'Coffee',
        'user_id': 'user_123',
        // Missing: count, todaycount, increment_by, reminder, reminder_value
      };

      final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDoc.id).thenReturn('test_item_1');
      when(() => mockDoc.data()).thenReturn(map);

      // Act
      final result = ItemModel.fromFirestore(mockDoc);

      // Assert
      expect(result.count, 0);
      expect(result.todayCount, 0);
      expect(result.incrementBy, 1);
      expect(result.reminder, ReminderType.none);
      expect(result.reminderValue, 0);
    });
  });
}
