import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/bluetooth/data/models/device_last_reset_time.dart';
import 'package:traxelos/features/items/domain/entities/item.dart';

void main() {
  final now = DateTime(2026, 10, 2, 17, 0);
  final midnightSeconds = DateTime(2026, 10, 2).toUtc().millisecondsSinceEpoch ~/ 1000;

  Item item({DateTime? lastResetTime, required DateTime lastUpdated}) => Item(
        id: 'i',
        name: 'Test',
        count: 10,
        todayCount: 10,
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        lastResetTime: lastResetTime,
        lastUpdated: lastUpdated,
        userId: 'u',
      );

  test('never-reset item touched today is sent today\'s midnight, not 0', () {
    // nRF zeroes todaycount on wake when lastResetTime predates midnight;
    // 0 would wipe the counts made since the item was created.
    final result = deviceLastResetTimeSeconds(
      item(lastUpdated: DateTime(2026, 10, 2, 16, 7)),
      now: now,
    );
    expect(result, midnightSeconds);
  });

  test('never-reset item last touched before today is still sent 0', () {
    // Its todaycount is from an earlier day, so a reset on the device is right.
    final result = deviceLastResetTimeSeconds(
      item(lastUpdated: DateTime(2026, 10, 1, 23, 59)),
      now: now,
    );
    expect(result, 0);
  });

  test('a stored lastResetTime is sent unchanged', () {
    final stored = DateTime(2026, 9, 30, 8, 0);
    final result = deviceLastResetTimeSeconds(
      item(lastResetTime: stored, lastUpdated: DateTime(2026, 10, 2, 12)),
      now: now,
    );
    expect(result, stored.toUtc().millisecondsSinceEpoch ~/ 1000);
  });
}
