import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/events/domain/entities/event_log.dart';
import 'package:traxelos/features/items/domain/utils/interval_calculator.dart';

/// Helper to create an EventLog with minimal boilerplate.
EventLog _event({
  required String eventName,
  required DateTime createdTime,
  int resetNumber = 0,
  int increment = 0,
  int currentCount = 0,
  String id = '',
}) {
  return EventLog(
    id: id.isEmpty ? '$eventName-$resetNumber-${createdTime.millisecondsSinceEpoch}' : id,
    createdTime: createdTime,
    itemId: 'item_1',
    eventName: eventName,
    increment: increment,
    currentCount: currentCount,
    resetNumber: resetNumber,
    userId: 'user_1',
  );
}

void main() {
  group('IntervalCalculator.calculate', () {
    test('should return empty list for empty events', () {
      final result = IntervalCalculator.calculate(events: []);
      expect(result, isEmpty);
    });

    group('single interval (no resets)', () {
      test('should return Total + one interval', () {
        final events = [
          _event(
            eventName: 'created',
            createdTime: DateTime(2025, 1, 1, 10, 0),
            resetNumber: 0,
          ),
          _event(
            eventName: 'increment',
            createdTime: DateTime(2025, 1, 1, 12, 0),
            resetNumber: 0,
            increment: 3,
            currentCount: 3,
          ),
        ];

        final result = IntervalCalculator.calculate(events: events);

        expect(result, hasLength(2));
        // Total row
        expect(result[0].intervalNumber, -1);
        expect(result[0].count, 3);
        // Interval 0
        expect(result[1].intervalNumber, 0);
        expect(result[1].count, 3);
      });

      test('current interval should have endTime null and isCurrent true', () {
        final events = [
          _event(
            eventName: 'created',
            createdTime: DateTime(2025, 1, 1, 10, 0),
          ),
          _event(
            eventName: 'increment',
            createdTime: DateTime(2025, 1, 2, 10, 0),
            increment: 1,
          ),
        ];

        final result = IntervalCalculator.calculate(events: events);

        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        expect(interval0.endTime, isNull);
        expect(interval0.isCurrent, isTrue);
      });

      test('should use created event as start time for interval 0', () {
        final createdTime = DateTime(2025, 1, 1, 10, 0);
        final events = [
          _event(eventName: 'created', createdTime: createdTime),
          _event(
            eventName: 'increment',
            createdTime: DateTime(2025, 1, 2, 10, 0),
            increment: 1,
          ),
        ];

        final result = IntervalCalculator.calculate(events: events);

        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        expect(interval0.startTime, createdTime);
      });
    });

    group('reset closes interval (endTime)', () {
      test('reset event should set endTime on the interval', () {
        final resetTime = DateTime(2025, 1, 5, 14, 30);
        final events = [
          _event(
            eventName: 'created',
            createdTime: DateTime(2025, 1, 1, 10, 0),
            resetNumber: 0,
          ),
          _event(
            eventName: 'increment',
            createdTime: DateTime(2025, 1, 2, 10, 0),
            resetNumber: 0,
            increment: 5,
            currentCount: 5,
          ),
          _event(
            eventName: 'reset',
            createdTime: resetTime,
            resetNumber: 0,
          ),
        ];

        final result = IntervalCalculator.calculate(events: events);

        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        expect(interval0.endTime, resetTime);
        expect(interval0.isCurrent, isFalse);
      });

      test('interval without reset event should have endTime null', () {
        final events = [
          _event(
            eventName: 'created',
            createdTime: DateTime(2025, 1, 1, 10, 0),
            resetNumber: 0,
          ),
          _event(
            eventName: 'increment',
            createdTime: DateTime(2025, 1, 2, 10, 0),
            resetNumber: 0,
            increment: 2,
          ),
        ];

        final result = IntervalCalculator.calculate(events: events);

        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        expect(interval0.endTime, isNull);
        expect(interval0.isCurrent, isTrue);
      });
    });

    group('multiple intervals', () {
      late DateTime createdTime;
      late DateTime reset0Time;
      late DateTime reset1Time;
      late List<EventLog> events;

      setUp(() {
        createdTime = DateTime(2025, 1, 1, 10, 0);
        reset0Time = DateTime(2025, 1, 10, 14, 0);
        reset1Time = DateTime(2025, 1, 20, 14, 0);

        events = [
          // Interval 0: created, 3 increments, reset
          _event(eventName: 'created', createdTime: createdTime, resetNumber: 0),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 2), resetNumber: 0, increment: 1, currentCount: 1),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 3), resetNumber: 0, increment: 2, currentCount: 3),
          _event(eventName: 'reset', createdTime: reset0Time, resetNumber: 0),
          // Interval 1: 2 increments, reset
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 11), resetNumber: 1, increment: 4, currentCount: 4),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 12), resetNumber: 1, increment: 1, currentCount: 5),
          _event(eventName: 'reset', createdTime: reset1Time, resetNumber: 1),
          // Interval 2: current (no reset)
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 21), resetNumber: 2, increment: 7, currentCount: 7),
        ];
      });

      test('should return Total + 3 intervals', () {
        final result = IntervalCalculator.calculate(events: events);
        expect(result, hasLength(4)); // Total + 3 intervals
      });

      test('Total row should sum all interval counts', () {
        final result = IntervalCalculator.calculate(events: events);
        final total = result.firstWhere((i) => i.intervalNumber == -1);
        expect(total.count, 1 + 2 + 4 + 1 + 7); // 15
      });

      test('intervals should be ordered most recent first', () {
        final result = IntervalCalculator.calculate(events: events);
        // Skip Total at index 0
        expect(result[1].intervalNumber, 2); // Most recent
        expect(result[2].intervalNumber, 1);
        expect(result[3].intervalNumber, 0); // Oldest
      });

      test('closed intervals should have correct endTime', () {
        final result = IntervalCalculator.calculate(events: events);

        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        final interval1 = result.firstWhere((i) => i.intervalNumber == 1);

        expect(interval0.endTime, reset0Time);
        expect(interval0.isCurrent, isFalse);
        expect(interval1.endTime, reset1Time);
        expect(interval1.isCurrent, isFalse);
      });

      test('current interval should have no endTime', () {
        final result = IntervalCalculator.calculate(events: events);
        final interval2 = result.firstWhere((i) => i.intervalNumber == 2);

        expect(interval2.endTime, isNull);
        expect(interval2.isCurrent, isTrue);
      });

      test('interval N start time should be reset time of interval N-1', () {
        final result = IntervalCalculator.calculate(events: events);

        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        final interval1 = result.firstWhere((i) => i.intervalNumber == 1);
        final interval2 = result.firstWhere((i) => i.intervalNumber == 2);

        expect(interval0.startTime, createdTime);
        expect(interval1.startTime, reset0Time); // Starts when interval 0 ended
        expect(interval2.startTime, reset1Time); // Starts when interval 1 ended
      });

      test('each interval should have correct count', () {
        final result = IntervalCalculator.calculate(events: events);

        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        final interval1 = result.firstWhere((i) => i.intervalNumber == 1);
        final interval2 = result.firstWhere((i) => i.intervalNumber == 2);

        expect(interval0.count, 3); // 1 + 2
        expect(interval1.count, 5); // 4 + 1
        expect(interval2.count, 7);
      });
    });

    group('edge case: most recent interval is closed (all cycles reset)', () {
      test('should have endTime set even on the most recent interval', () {
        final resetTime = DateTime(2025, 2, 1, 8, 0);
        final events = [
          _event(eventName: 'created', createdTime: DateTime(2025, 1, 1), resetNumber: 0),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 5), resetNumber: 0, increment: 10),
          _event(eventName: 'reset', createdTime: resetTime, resetNumber: 0),
          // No events for interval 1 — new cycle just started, no activity
        ];

        final result = IntervalCalculator.calculate(events: events);

        // Only Total + interval 0 (no events for interval 1 so it doesn't appear)
        expect(result, hasLength(2));
        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        expect(interval0.endTime, resetTime);
        expect(interval0.isCurrent, isFalse);
      });
    });

    group('count calculation', () {
      test('should exclude reset and created events from count', () {
        final events = [
          _event(eventName: 'created', createdTime: DateTime(2025, 1, 1), increment: 0),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 2), increment: 5),
          _event(eventName: 'reset', createdTime: DateTime(2025, 1, 3), increment: 0),
        ];

        final result = IntervalCalculator.calculate(events: events);
        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        expect(interval0.count, 5);
      });

      test('should sum multiple increments in same interval', () {
        final events = [
          _event(eventName: 'created', createdTime: DateTime(2025, 1, 1)),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 2), increment: 3),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 3), increment: 7),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 4), increment: 2),
        ];

        final result = IntervalCalculator.calculate(events: events);
        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        expect(interval0.count, 12);
      });
    });

    group('maxIntervals', () {
      test('should limit number of intervals returned', () {
        final events = [
          _event(eventName: 'created', createdTime: DateTime(2025, 1, 1), resetNumber: 0),
          _event(eventName: 'reset', createdTime: DateTime(2025, 1, 2), resetNumber: 0),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 3), resetNumber: 1, increment: 1),
          _event(eventName: 'reset', createdTime: DateTime(2025, 1, 4), resetNumber: 1),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 5), resetNumber: 2, increment: 1),
          _event(eventName: 'reset', createdTime: DateTime(2025, 1, 6), resetNumber: 2),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 7), resetNumber: 3, increment: 1),
        ];

        final result = IntervalCalculator.calculate(events: events, maxIntervals: 2);

        // Total + 2 most recent intervals
        expect(result, hasLength(3));
        expect(result[0].intervalNumber, -1); // Total
        expect(result[1].intervalNumber, 3); // Most recent
        expect(result[2].intervalNumber, 2); // Second most recent
      });
    });

    group('start time fallbacks', () {
      test('interval 0 without created event should use earliest event', () {
        final earliestTime = DateTime(2025, 1, 5);
        final events = [
          // No 'created' event — only increments
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 10), increment: 1),
          _event(eventName: 'increment', createdTime: earliestTime, increment: 2),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 8), increment: 3),
        ];

        final result = IntervalCalculator.calculate(events: events);
        final interval0 = result.firstWhere((i) => i.intervalNumber == 0);
        expect(interval0.startTime, earliestTime);
      });

      test('interval N without previous reset should use earliest event in that interval', () {
        final earliestInInterval1 = DateTime(2025, 1, 15);
        final events = [
          // Interval 0: no reset event (unusual but possible with partial data)
          _event(eventName: 'created', createdTime: DateTime(2025, 1, 1), resetNumber: 0),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 2), resetNumber: 0, increment: 1),
          // Interval 1: no reset event for interval 0, so falls back to earliest event
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 20), resetNumber: 1, increment: 1),
          _event(eventName: 'increment', createdTime: earliestInInterval1, resetNumber: 1, increment: 1),
        ];

        final result = IntervalCalculator.calculate(events: events);
        final interval1 = result.firstWhere((i) => i.intervalNumber == 1);
        expect(interval1.startTime, earliestInInterval1);
      });
    });

    group('Total (All Time) row', () {
      test('should have intervalNumber -1', () {
        final events = [
          _event(eventName: 'created', createdTime: DateTime(2025, 1, 1)),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 2), increment: 1),
        ];

        final result = IntervalCalculator.calculate(events: events);
        expect(result[0].intervalNumber, -1);
      });

      test('should have endTime null (ongoing)', () {
        final events = [
          _event(eventName: 'created', createdTime: DateTime(2025, 1, 1)),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 2), increment: 1),
        ];

        final result = IntervalCalculator.calculate(events: events);
        expect(result[0].endTime, isNull);
      });

      test('should use earliest event across all intervals as startTime', () {
        final earliest = DateTime(2025, 1, 1, 10, 0);
        final events = [
          _event(eventName: 'created', createdTime: earliest, resetNumber: 0),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 5), resetNumber: 0, increment: 1),
          _event(eventName: 'reset', createdTime: DateTime(2025, 1, 10), resetNumber: 0),
          _event(eventName: 'increment', createdTime: DateTime(2025, 1, 15), resetNumber: 1, increment: 1),
        ];

        final result = IntervalCalculator.calculate(events: events);
        expect(result[0].startTime, earliest);
      });
    });
  });

  group('IntervalCalculator.formatDuration', () {
    test('should format minutes only', () {
      expect(IntervalCalculator.formatDuration(const Duration(minutes: 45)), '45m');
    });

    test('should format 0 minutes', () {
      expect(IntervalCalculator.formatDuration(Duration.zero), '0m');
    });

    test('should format hours and minutes', () {
      expect(IntervalCalculator.formatDuration(const Duration(hours: 2, minutes: 30)), '2h 30m');
    });

    test('should format hours only when no minutes', () {
      expect(IntervalCalculator.formatDuration(const Duration(hours: 5)), '5h');
    });

    test('should format days and hours', () {
      expect(IntervalCalculator.formatDuration(const Duration(days: 3, hours: 4)), '3d 4h');
    });

    test('should format days only when no hours', () {
      expect(IntervalCalculator.formatDuration(const Duration(days: 2)), '2d');
    });

    test('should format weeks and days', () {
      expect(IntervalCalculator.formatDuration(const Duration(days: 9)), '1w 2d');
    });

    test('should format weeks only when no remaining days', () {
      expect(IntervalCalculator.formatDuration(const Duration(days: 14)), '2w');
    });
  });

  group('IntervalData', () {
    test('isCurrent should be true when endTime is null', () {
      final interval = IntervalData(
        intervalNumber: 0,
        count: 5,
        startTime: DateTime(2025, 1, 1),
        endTime: null,
      );
      expect(interval.isCurrent, isTrue);
    });

    test('isCurrent should be false when endTime is set', () {
      final interval = IntervalData(
        intervalNumber: 0,
        count: 5,
        startTime: DateTime(2025, 1, 1),
        endTime: DateTime(2025, 1, 10),
      );
      expect(interval.isCurrent, isFalse);
    });

    test('duration should use endTime when set', () {
      final start = DateTime(2025, 1, 1);
      final end = DateTime(2025, 1, 4);
      final interval = IntervalData(
        intervalNumber: 0,
        count: 0,
        startTime: start,
        endTime: end,
      );
      expect(interval.duration, const Duration(days: 3));
    });

    test('props should include all fields for equality', () {
      final a = IntervalData(
        intervalNumber: 0,
        count: 5,
        startTime: DateTime(2025, 1, 1),
        endTime: DateTime(2025, 1, 10),
      );
      final b = IntervalData(
        intervalNumber: 0,
        count: 5,
        startTime: DateTime(2025, 1, 1),
        endTime: DateTime(2025, 1, 10),
      );
      expect(a, equals(b));
    });
  });
}
