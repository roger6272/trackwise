import 'package:equatable/equatable.dart';

import '../../domain/entities/chart_data.dart';

/// Base event class for Charts BLoC.
///
/// All chart-related events extend this class and use Equatable for value equality.
/// Events represent user actions that trigger BLoC state changes.
abstract class ChartsEvent extends Equatable {
  const ChartsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load bar chart data.
///
/// Fetches events and aggregates them by the specified level.
/// Uses GetChartDataUseCase to generate the chart data.
///
/// Example:
/// ```dart
/// bloc.add(LoadBarChart(
///   startDate: DateTime(2024, 1, 1),
///   endDate: DateTime(2024, 1, 31),
///   aggregationLevel: AggregationLevel.daily,
/// ));
/// ```
class LoadBarChart extends ChartsEvent {
  final DateTime startDate;
  final DateTime endDate;
  final AggregationLevel aggregationLevel;

  /// Optional item ID to filter chart data to a specific item.
  final String? itemId;

  /// Optional time to filter events after (for "since last reset" mode).
  final DateTime? sinceResetTime;

  const LoadBarChart({
    required this.startDate,
    required this.endDate,
    this.aggregationLevel = AggregationLevel.daily,
    this.itemId,
    this.sinceResetTime,
  });

  @override
  List<Object?> get props => [startDate, endDate, aggregationLevel, itemId, sinceResetTime];
}

/// Event to load cumulative chart data.
///
/// Fetches events and calculates a running total over time.
/// Uses GetCumulativeChartDataUseCase.
///
/// Example:
/// ```dart
/// bloc.add(LoadCumulativeChart(
///   startDate: DateTime(2024, 1, 1),
///   endDate: DateTime(2024, 1, 31),
/// ));
/// ```
class LoadCumulativeChart extends ChartsEvent {
  final DateTime startDate;
  final DateTime endDate;

  /// Optional item ID to filter cumulative data to a specific item.
  final String? itemId;

  /// Optional time to filter events after (for "since last reset" mode).
  final DateTime? sinceResetTime;

  const LoadCumulativeChart({
    required this.startDate,
    required this.endDate,
    this.itemId,
    this.sinceResetTime,
  });

  @override
  List<Object?> get props => [startDate, endDate, itemId, sinceResetTime];
}

/// Event to change the date range.
///
/// Reloads the current chart type with a new date range.
/// Preserves the current chart type (bar or cumulative).
///
/// Example:
/// ```dart
/// bloc.add(ChangeDateRange(
///   startDate: DateTime(2024, 2, 1),
///   endDate: DateTime(2024, 2, 28),
/// ));
/// ```
class ChangeDateRange extends ChartsEvent {
  final DateTime startDate;
  final DateTime endDate;

  const ChangeDateRange({
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [startDate, endDate];
}

/// Event to change the aggregation level.
///
/// Reloads the bar chart with a new aggregation level.
/// Only applies to bar charts (cumulative always uses daily).
///
/// Example:
/// ```dart
/// bloc.add(ChangeAggregationLevel(AggregationLevel.weekly));
/// ```
class ChangeAggregationLevel extends ChartsEvent {
  final AggregationLevel aggregationLevel;

  const ChangeAggregationLevel(this.aggregationLevel);

  @override
  List<Object?> get props => [aggregationLevel];
}

/// Event to refresh current chart data.
///
/// Reloads the chart with current settings.
/// Useful when new events have been added.
class RefreshChart extends ChartsEvent {
  const RefreshChart();
}
