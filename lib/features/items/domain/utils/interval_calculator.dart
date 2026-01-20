import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../events/domain/entities/event_log.dart';

/// Represents a single interval (reset period) with its statistics.
class IntervalData extends Equatable {
  /// The reset number for this interval (0 = first interval).
  final int intervalNumber;

  /// Total count of increments in this interval.
  final int count;

  /// Start time of this interval (created/reset event time).
  final DateTime startTime;

  /// End time of this interval (next reset event time, or null if current).
  final DateTime? endTime;

  /// Whether this is the current (most recent) interval.
  bool get isCurrent => endTime == null;

  /// Duration of this interval.
  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  const IntervalData({
    required this.intervalNumber,
    required this.count,
    required this.startTime,
    this.endTime,
  });

  @override
  List<Object?> get props => [intervalNumber, count, startTime, endTime];
}

/// Calculator for interval-based statistics from event logs.
///
/// Groups events by resetNumber and calculates:
/// - Count per interval (sum of increments)
/// - Interval duration (start to end time)
/// - Total across all intervals
class IntervalCalculator {
  /// Calculate interval data from a list of events.
  ///
  /// Returns a list of [IntervalData] ordered by most recent first.
  /// The first element is always "Total" (all intervals combined).
  ///
  /// [events] - All events for an item.
  /// [maxIntervals] - Maximum number of intervals to return (excluding total).
  static List<IntervalData> calculate({
    required List<EventLog> events,
    int maxIntervals = 10,
  }) {
    if (events.isEmpty) return [];

    // Debug: Log all events being processed
    debugPrint('📊 IntervalCalculator processing ${events.length} events:');
    for (final e in events) {
      debugPrint('  - ${e.eventName}: increment=${e.increment}, count=${e.currentCount}, time=${e.createdTime}, id=${e.id}');
    }

    // Group events by resetNumber
    final Map<int, List<EventLog>> eventsByInterval = {};
    for (final event in events) {
      eventsByInterval.putIfAbsent(event.resetNumber, () => []).add(event);
    }

    // Sort intervals by resetNumber descending (most recent first)
    final sortedIntervalNumbers = eventsByInterval.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // First pass: collect reset event times and other metadata per interval
    // Reset event with resetNumber=N marks the END of interval N
    // and the START of interval N+1
    final Map<int, DateTime> resetTimeByInterval = {};
    final Map<int, DateTime?> createdTimeByInterval = {};
    final Map<int, int> countByInterval = {};
    DateTime? earliestStart;
    int totalCount = 0;

    for (final intervalNumber in eventsByInterval.keys) {
      final intervalEvents = eventsByInterval[intervalNumber]!;
      int intervalCount = 0;

      for (final event in intervalEvents) {
        // Track reset event time (marks end of this interval)
        if (event.eventName == 'reset') {
          resetTimeByInterval[intervalNumber] = event.createdTime;
        }

        // Track created event time (only for interval 0)
        if (event.eventName == 'created') {
          createdTimeByInterval[intervalNumber] = event.createdTime;
        }

        // Track earliest event for total start time
        if (earliestStart == null ||
            event.createdTime.isBefore(earliestStart)) {
          earliestStart = event.createdTime;
        }

        // Sum increments (exclude reset/created)
        if (event.eventName != 'reset' && event.eventName != 'created') {
          intervalCount += event.increment;
          totalCount += event.increment;
        }
      }

      countByInterval[intervalNumber] = intervalCount;
    }

    final results = <IntervalData>[];

    // Add total row first
    if (earliestStart != null) {
      results.add(IntervalData(
        intervalNumber: -1, // Special marker for total
        count: totalCount,
        startTime: earliestStart,
        endTime: null, // Total has no end (ongoing)
      ));
    }

    // Process each interval (limited to maxIntervals)
    for (int i = 0; i < sortedIntervalNumbers.length && i < maxIntervals; i++) {
      final intervalNumber = sortedIntervalNumbers[i];
      final isCurrent = i == 0;

      // Determine start time:
      // - For interval 0: use 'created' event time, or earliest event
      // - For interval N (N>0): use reset time from interval N-1 (previous reset)
      DateTime? intervalStart;
      if (intervalNumber == 0) {
        // First interval: use created event or find earliest event
        intervalStart = createdTimeByInterval[0];
        if (intervalStart == null) {
          // Fallback: find earliest event in interval 0
          for (final event in eventsByInterval[0]!) {
            if (intervalStart == null ||
                event.createdTime.isBefore(intervalStart)) {
              intervalStart = event.createdTime;
            }
          }
        }
      } else {
        // For interval N, start = when previous interval ended (reset N-1)
        intervalStart = resetTimeByInterval[intervalNumber - 1];
        if (intervalStart == null) {
          // Fallback: find earliest event in this interval
          for (final event in eventsByInterval[intervalNumber]!) {
            if (intervalStart == null ||
                event.createdTime.isBefore(intervalStart)) {
              intervalStart = event.createdTime;
            }
          }
        }
      }

      // End time: reset event in this interval (null if current)
      final intervalEnd = isCurrent ? null : resetTimeByInterval[intervalNumber];

      if (intervalStart != null) {
        results.add(IntervalData(
          intervalNumber: intervalNumber,
          count: countByInterval[intervalNumber] ?? 0,
          startTime: intervalStart,
          endTime: intervalEnd,
        ));
      }
    }

    return results;
  }

  /// Format a duration as a human-readable string.
  ///
  /// Examples: "2h 30m", "3d 4h", "1w 2d"
  static String formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days >= 7) {
      final weeks = days ~/ 7;
      final remainingDays = days % 7;
      if (remainingDays > 0) {
        return '${weeks}w ${remainingDays}d';
      }
      return '${weeks}w';
    } else if (days > 0) {
      if (hours > 0) {
        return '${days}d ${hours}h';
      }
      return '${days}d';
    } else if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }
}
