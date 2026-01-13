import 'package:equatable/equatable.dart';

import '../../domain/entities/chart_data.dart';

/// Type of chart being displayed.
enum ChartType {
  /// Bar chart showing aggregated values per period
  bar,

  /// Line chart showing cumulative (running total) values
  cumulative,
}

/// Base state class for Charts BLoC.
///
/// All chart-related states extend this class and use Equatable for value equality.
/// States represent the current status of the charts feature in the UI.
abstract class ChartsState extends Equatable {
  const ChartsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any chart data is loaded.
///
/// This is the starting state when the BLoC is first created.
/// The UI should show a placeholder or trigger LoadBarChart/LoadCumulativeChart.
class ChartsInitial extends ChartsState {
  const ChartsInitial();
}

/// Loading state while fetching and processing chart data.
///
/// Emitted during:
/// - Initial load (LoadBarChart, LoadCumulativeChart)
/// - Date range changes (ChangeDateRange)
/// - Aggregation level changes (ChangeAggregationLevel)
///
/// The UI should show a loading indicator.
class ChartsLoading extends ChartsState {
  const ChartsLoading();
}

/// Success state with loaded chart data.
///
/// Contains the chart data and current settings for display.
/// The UI should render the chart based on chartType.
class ChartsLoaded extends ChartsState {
  /// The aggregated chart data to display.
  final ChartData chartData;

  /// The type of chart (bar or cumulative).
  final ChartType chartType;

  /// Start of the current date range.
  final DateTime startDate;

  /// End of the current date range.
  final DateTime endDate;

  /// Optional item ID if filtering by item.
  final String? itemId;

  const ChartsLoaded({
    required this.chartData,
    required this.chartType,
    required this.startDate,
    required this.endDate,
    this.itemId,
  });

  @override
  List<Object?> get props => [chartData, chartType, startDate, endDate, itemId];

  /// Create a copy with updated fields.
  ChartsLoaded copyWith({
    ChartData? chartData,
    ChartType? chartType,
    DateTime? startDate,
    DateTime? endDate,
    String? itemId,
  }) {
    return ChartsLoaded(
      chartData: chartData ?? this.chartData,
      chartType: chartType ?? this.chartType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      itemId: itemId ?? this.itemId,
    );
  }

  /// Whether filtering by a specific item.
  bool get isFilteringByItem => itemId != null;

  /// Current aggregation level from the chart data.
  AggregationLevel get aggregationLevel => chartData.aggregationLevel;

  /// Whether this is a bar chart.
  bool get isBarChart => chartType == ChartType.bar;

  /// Whether this is a cumulative chart.
  bool get isCumulativeChart => chartType == ChartType.cumulative;
}

/// Error state with failure message.
///
/// Emitted when:
/// - Firestore operation fails (ServerFailure)
/// - User not authenticated (AuthFailure)
///
/// The UI should display the error message to the user.
class ChartsError extends ChartsState {
  /// Human-readable error message extracted from Failure.message
  final String message;

  const ChartsError(this.message);

  @override
  List<Object?> get props => [message];
}
