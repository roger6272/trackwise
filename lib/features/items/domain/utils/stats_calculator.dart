import 'package:equatable/equatable.dart';

import '../../../events/domain/entities/event_log.dart';

/// Result of period-based statistics calculation.
///
/// Contains totals, comparisons, and averages for a given time period.
class StatsResult extends Equatable {
  /// Sum of increments for the selected period.
  final int totalCount;

  /// Sum of increments for the previous period (for comparison).
  final int priorPeriodCount;

  /// Percent change from prior period: (current - prior) / prior.
  /// Null if prior period count is 0 to avoid division by zero.
  final double? percentChange;

  /// Label describing the comparison period: 'DoD', 'WoW', or 'MoM'.
  final String periodLabel;

  /// Average count per time unit (hourly for 1D, daily for 7D/30D).
  final double average;

  const StatsResult({
    required this.totalCount,
    required this.priorPeriodCount,
    required this.percentChange,
    required this.periodLabel,
    required this.average,
  });

  /// Whether the percent change is positive (current > prior).
  bool get isPositive => percentChange != null && percentChange! > 0;

  /// Whether the percent change is negative (current < prior).
  bool get isNegative => percentChange != null && percentChange! < 0;

  @override
  List<Object?> get props => [
        totalCount,
        priorPeriodCount,
        percentChange,
        periodLabel,
        average,
      ];
}

/// Calculator for period-based statistics from event logs.
///
/// Replaces FlutterFlow custom_functions.dart logic for:
/// - totalincrements
/// - totalincrementsPrior
/// - totalincrementsPoP
/// - totalincrementsAverage
class StatsCalculator {
  /// Calculates statistics for a given period and events.
  ///
  /// [events] - List of EventLog entries to analyze.
  /// [aggregation] - Time period: '1D' (1 day), '7D' (7 days), or '30D' (30 days).
  /// [endDate] - The end date of the period (inclusive of that day).
  /// [lastResetTime] - Optional reset time for filtering events.
  /// [sinceResetOnly] - If true, only include events after [lastResetTime].
  static StatsResult calculate({
    required List<EventLog> events,
    required String aggregation,
    required DateTime endDate,
    DateTime? lastResetTime,
    bool sinceResetOnly = false,
  }) {
    // Determine period days based on aggregation
    final periodDays = _getPeriodDays(aggregation);

    // Calculate date ranges for current and prior periods
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day)
        .add(const Duration(days: 1));
    final currentPeriodStart =
        endOfDay.subtract(Duration(days: periodDays));
    final priorPeriodStart =
        currentPeriodStart.subtract(Duration(days: periodDays));
    final priorPeriodEnd = currentPeriodStart;

    // Filter events, excluding 'reset' events
    final filteredEvents = events.where((e) => e.eventName != 'reset');

    // Sum increments for current period
    final currentPeriodEvents = filteredEvents.where((e) {
      final t = e.createdTime;
      final inRange =
          t.isAfter(currentPeriodStart) && t.isBefore(endOfDay);
      if (!inRange) return false;

      // Apply reset filter if enabled
      if (sinceResetOnly && lastResetTime != null) {
        return t.isAfter(lastResetTime);
      }
      return true;
    });

    final totalCount =
        currentPeriodEvents.fold<int>(0, (sum, e) => sum + e.increment);

    // Sum increments for prior period
    final priorPeriodEvents = filteredEvents.where((e) {
      final t = e.createdTime;
      final inRange =
          t.isAfter(priorPeriodStart) && t.isBefore(priorPeriodEnd);
      if (!inRange) return false;

      // Apply reset filter if enabled
      if (sinceResetOnly && lastResetTime != null) {
        return t.isAfter(lastResetTime);
      }
      return true;
    });

    final priorPeriodCount =
        priorPeriodEvents.fold<int>(0, (sum, e) => sum + e.increment);

    // Calculate percent change (null if prior is 0)
    final double? percentChange;
    if (priorPeriodCount == 0) {
      percentChange = null;
    } else {
      percentChange =
          (totalCount - priorPeriodCount) / priorPeriodCount;
    }

    // Determine period label
    final periodLabel = _getPeriodLabel(aggregation);

    // Calculate average (hourly for 1D, daily for 7D/30D)
    final divisor = aggregation == '1D' ? 24 : periodDays;
    final average = totalCount / divisor;

    return StatsResult(
      totalCount: totalCount,
      priorPeriodCount: priorPeriodCount,
      percentChange: percentChange,
      periodLabel: periodLabel,
      average: average,
    );
  }

  /// Returns the number of days for the given aggregation.
  static int _getPeriodDays(String aggregation) {
    switch (aggregation) {
      case '1D':
        return 1;
      case '7D':
        return 7;
      case '30D':
        return 30;
      default:
        return 1;
    }
  }

  /// Returns the period comparison label for the given aggregation.
  static String _getPeriodLabel(String aggregation) {
    switch (aggregation) {
      case '1D':
        return 'DoD';
      case '7D':
        return 'WoW';
      case '30D':
        return 'MoM';
      default:
        return 'DoD';
    }
  }
}
