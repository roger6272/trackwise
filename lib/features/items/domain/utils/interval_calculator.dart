import 'package:equatable/equatable.dart';

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

    // Group events by resetNumber
    final Map<int, List<EventLog>> eventsByInterval = {};
    for (final event in events) {
      eventsByInterval.putIfAbsent(event.resetNumber, () => []).add(event);
    }

    // Sort intervals by resetNumber descending (most recent first)
    final sortedIntervalNumbers = eventsByInterval.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Calculate total across all intervals
    int totalCount = 0;
    DateTime? earliestStart;
    for (final intervalEvents in eventsByInterval.values) {
      for (final event in intervalEvents) {
        if (event.eventName != 'reset' && event.eventName != 'created') {
          totalCount += event.increment;
        }
        // Track earliest event for total start time
        if (earliestStart == null ||
            event.createdTime.isBefore(earliestStart)) {
          earliestStart = event.createdTime;
        }
      }
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
      final intervalEvents = eventsByInterval[intervalNumber]!;

      // Calculate count for this interval (exclude reset/created events)
      int intervalCount = 0;
      DateTime? intervalStart;
      DateTime? intervalEnd;

      for (final event in intervalEvents) {
        // Find start time (created event or first event)
        if (event.eventName == 'created' ||
            (intervalStart == null ||
                event.createdTime.isBefore(intervalStart))) {
          if (event.eventName == 'created') {
            intervalStart = event.createdTime;
          } else if (intervalStart == null) {
            intervalStart = event.createdTime;
          }
        }

        // Find end time (reset event marks end of this interval)
        if (event.eventName == 'reset') {
          intervalEnd = event.createdTime;
        }

        // Sum increments (exclude reset/created)
        if (event.eventName != 'reset' && event.eventName != 'created') {
          intervalCount += event.increment;
        }
      }

      // For the first interval (highest resetNumber), it's current - no end time
      final isCurrent = i == 0;

      if (intervalStart != null) {
        results.add(IntervalData(
          intervalNumber: intervalNumber,
          count: intervalCount,
          startTime: intervalStart,
          endTime: isCurrent ? null : intervalEnd,
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
